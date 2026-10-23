#import "RNTLSSocket.h"
#import "RNCommon.h"

#include "mbedtls/build_info.h"
#include "mbedtls/ssl.h"
#include "mbedtls/net_sockets.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/x509_crt.h"
#include "mbedtls/error.h"
#if defined(MBEDTLS_PSA_CRYPTO_C)
#include "psa/crypto.h"
#endif

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <poll.h>
#include <string.h>
#include <stdio.h>

static mbedtls_x509_crt g_cacert;
static BOOL g_caLoaded = NO;
static NSInteger g_caCount = 0;
static dispatch_once_t g_caOnce;

static NSString *RNMbedError(int ret)
{
    char buf[200];
    mbedtls_strerror(ret, buf, sizeof(buf));
    return [NSString stringWithFormat:@"%s (-0x%04x)", buf, (unsigned int)(-ret)];
}

static void RNSetError(NSError **error, NSInteger code, NSString *message)
{
    if (error) *error = RNMakeError(code, message);
}

static void RNLoadCABundle(void)
{
    mbedtls_x509_crt_init(&g_cacert);
#if defined(MBEDTLS_PSA_CRYPTO_C)
    psa_status_t st = psa_crypto_init();
    if (st != PSA_SUCCESS) RNLog(@"psa_crypto_init failed: %d", (int)st);
#endif
    NSString *path = [[NSBundle mainBundle] pathForResource:@"cacert" ofType:@"pem"];
    if (!path) {
        RNLog(@"cacert.pem is missing from the app bundle");
        return;
    }
    NSData *pem = [NSData dataWithContentsOfFile:path];
    if (!pem.length) {
        RNLog(@"cacert.pem is empty");
        return;
    }
    NSMutableData *buf = [pem mutableCopy];
    uint8_t zero = 0;
    [buf appendBytes:&zero length:1]; // PEM input must be NUL terminated, length includes NUL
    int ret = mbedtls_x509_crt_parse(&g_cacert, (const unsigned char *)buf.bytes, buf.length);
    if (ret < 0) {
        RNLog(@"Failed to parse cacert.pem: %@", RNMbedError(ret));
        return;
    }
    int count = 0;
    for (mbedtls_x509_crt *c = &g_cacert; c != NULL && c->version > 0; c = c->next) count++;
    g_caCount = count;
    g_caLoaded = (count > 0);
    RNLog(@"Loaded CA bundle: %ld certificates", (long)count);
}

@interface RNTLSSocket () {
    int _fd;
    int _pipeCancel[2];
    BOOL _connected;
    BOOL _cancelled;
    int _readTimeoutMs;

    mbedtls_ssl_context _ssl;
    mbedtls_ssl_config _conf;
    mbedtls_ctr_drbg_context _ctr_drbg;
    mbedtls_entropy_context _entropy;
    BOOL _sslInited;
}
@end

static int rn_net_send(void *ctx, const unsigned char *buf, size_t len)
{
    int fd = *(int *)ctx;
    ssize_t ret = write(fd, buf, len);
    if (ret < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) return MBEDTLS_ERR_SSL_WANT_WRITE;
        if (errno == EPIPE || errno == ECONNRESET) return MBEDTLS_ERR_NET_CONN_RESET;
        return MBEDTLS_ERR_NET_SEND_FAILED;
    }
    return (int)ret;
}

static int rn_net_recv(void *ctx, unsigned char *buf, size_t len)
{
    int fd = *(int *)ctx;
    ssize_t ret = read(fd, buf, len);
    if (ret < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) return MBEDTLS_ERR_SSL_WANT_READ;
        if (errno == ECONNRESET) return MBEDTLS_ERR_NET_CONN_RESET;
        return MBEDTLS_ERR_NET_RECV_FAILED;
    }
    return (int)ret;
}

@implementation RNTLSSocket

+ (void)warmUp
{
    dispatch_once(&g_caOnce, ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            RNLoadCABundle();
        });
    });
}

+ (BOOL)caBundleAvailable
{
    dispatch_once(&g_caOnce, ^{ RNLoadCABundle(); });
    return g_caLoaded;
}

+ (NSInteger)caCertificateCount
{
    dispatch_once(&g_caOnce, ^{ RNLoadCABundle(); });
    return g_caCount;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _fd = -1;
        _pipeCancel[0] = -1;
        _pipeCancel[1] = -1;
        if (pipe(_pipeCancel) == 0) {
            fcntl(_pipeCancel[0], F_SETFL, O_NONBLOCK);
            fcntl(_pipeCancel[1], F_SETFL, O_NONBLOCK);
        }
    }
    return self;
}

- (void)dealloc
{
    [self close];
    if (_pipeCancel[0] >= 0) close(_pipeCancel[0]);
    if (_pipeCancel[1] >= 0) close(_pipeCancel[1]);
}

- (void)cancel
{
    @synchronized (self) {
        if (_cancelled) return;
        _cancelled = YES;
        if (_pipeCancel[1] >= 0) {
            char c = 'q';
            (void)write(_pipeCancel[1], &c, 1);
        }
    }
}

- (void)close
{
    @synchronized (self) {
        if (_sslInited) {
            mbedtls_ssl_close_notify(&_ssl);
            mbedtls_ssl_free(&_ssl);
            mbedtls_ssl_config_free(&_conf);
            mbedtls_ctr_drbg_free(&_ctr_drbg);
            mbedtls_entropy_free(&_entropy);
            _sslInited = NO;
        }
        if (_fd >= 0) {
            close(_fd);
            _fd = -1;
        }
        _connected = NO;
    }
}

- (BOOL)connectToHost:(NSString *)host port:(int)port verify:(BOOL)verify
     connectTimeoutMs:(int)connectMs readTimeoutMs:(int)readMs error:(NSError **)error
{
    _readTimeoutMs = readMs;

    struct addrinfo hints, *res = NULL, *rp;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    char portStr[16];
    snprintf(portStr, sizeof(portStr), "%d", port);
    int gai = getaddrinfo(host.UTF8String, portStr, &hints, &res);
    if (gai != 0 || !res) {
        RNSetError(error, RNErrorNetwork, [NSString stringWithFormat:@"Cannot resolve host %@: %s", host, gai_strerror(gai)]);
        return NO;
    }

    int fd = -1;
    for (rp = res; rp != NULL; rp = rp->ai_next) {
        fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (fd < 0) continue;

        int flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);

        int c = connect(fd, rp->ai_addr, rp->ai_addrlen);
        if (c == 0) break;
        if (errno == EINPROGRESS) {
            struct pollfd pfd;
            pfd.fd = fd;
            pfd.events = POLLOUT;
            int pr = poll(&pfd, 1, connectMs);
            if (pr > 0 && (pfd.revents & POLLOUT)) {
                int sockErr = 0;
                socklen_t slen = sizeof(sockErr);
                getsockopt(fd, SOL_SOCKET, SO_ERROR, &sockErr, &slen);
                if (sockErr == 0) break;
            }
        }
        close(fd);
        fd = -1;
    }
    freeaddrinfo(res);

    if (fd < 0) {
        RNSetError(error, RNErrorNetwork, [NSString stringWithFormat:@"Failed to connect to %@:%d", host, port]);
        return NO;
    }
    _fd = fd;

    int nodelay = 1;
    setsockopt(_fd, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));

    if (self.plain) {
        _connected = YES;
        return YES;
    }

    [RNTLSSocket caBundleAvailable];

    mbedtls_ssl_init(&_ssl);
    mbedtls_ssl_config_init(&_conf);
    mbedtls_ctr_drbg_init(&_ctr_drbg);
    mbedtls_entropy_init(&_entropy);
    _sslInited = YES;

    const char *pers = "realnews_ios6";
    int ret = mbedtls_ctr_drbg_seed(&_ctr_drbg, mbedtls_entropy_func, &_entropy,
                                    (const unsigned char *)pers, strlen(pers));
    if (ret != 0) {
        RNSetError(error, RNErrorTLS, [NSString stringWithFormat:@"TLS RNG seed failed: %@", RNMbedError(ret)]);
        [self close];
        return NO;
    }

    ret = mbedtls_ssl_config_defaults(&_conf,
                                       MBEDTLS_SSL_IS_CLIENT,
                                       MBEDTLS_SSL_TRANSPORT_STREAM,
                                       MBEDTLS_SSL_PRESET_DEFAULT);
    if (ret != 0) {
        RNSetError(error, RNErrorTLS, [NSString stringWithFormat:@"TLS config failed: %@", RNMbedError(ret)]);
        [self close];
        return NO;
    }

    mbedtls_ssl_conf_rng(&_conf, mbedtls_ctr_drbg_random, &_ctr_drbg);
#if defined(MBEDTLS_SSL_RENEGOTIATION)
    mbedtls_ssl_conf_renegotiation(&_conf, MBEDTLS_SSL_RENEGOTIATION_ENABLED);
#endif

    if (verify && g_caLoaded) {
        mbedtls_ssl_conf_authmode(&_conf, MBEDTLS_SSL_VERIFY_REQUIRED);
        mbedtls_ssl_conf_ca_chain(&_conf, &g_cacert, NULL);
    } else {
        mbedtls_ssl_conf_authmode(&_conf, MBEDTLS_SSL_VERIFY_NONE);
    }

    ret = mbedtls_ssl_setup(&_ssl, &_conf);
    if (ret != 0) {
        RNSetError(error, RNErrorTLS, [NSString stringWithFormat:@"TLS setup failed: %@", RNMbedError(ret)]);
        [self close];
        return NO;
    }

    mbedtls_ssl_set_hostname(&_ssl, host.UTF8String);
    mbedtls_ssl_set_bio(&_ssl, &_fd, rn_net_send, rn_net_recv, NULL);

    while ((ret = mbedtls_ssl_handshake(&_ssl)) != 0) {
        if (_cancelled) {
            RNSetError(error, RNErrorCancelled, @"Connection cancelled");
            [self close];
            return NO;
        }
        if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
            RNSetError(error, RNErrorTLS, [NSString stringWithFormat:@"TLS handshake failed: %@", RNMbedError(ret)]);
            [self close];
            return NO;
        }
        struct pollfd pfds[2];
        pfds[0].fd = _fd;
        pfds[0].events = (ret == MBEDTLS_ERR_SSL_WANT_READ) ? POLLIN : POLLOUT;
        pfds[1].fd = _pipeCancel[0];
        pfds[1].events = POLLIN;

        int pr = poll(pfds, 2, connectMs);
        if (pr <= 0 || (pfds[1].revents & POLLIN)) {
            RNSetError(error, _cancelled ? RNErrorCancelled : RNErrorTimeout,
                       _cancelled ? @"Connection cancelled" : @"TLS handshake timed out");
            [self close];
            return NO;
        }
    }

    _connected = YES;
    return YES;
}

- (BOOL)writeData:(NSData *)data error:(NSError **)error
{
    if (!_connected) {
        RNSetError(error, RNErrorNetwork, @"Socket not connected");
        return NO;
    }
    const unsigned char *p = (const unsigned char *)data.bytes;
    size_t left = data.length;

    while (left > 0) {
        if (_cancelled) {
            RNSetError(error, RNErrorCancelled, @"Write cancelled");
            return NO;
        }
        if (self.plain) {
            ssize_t w = write(_fd, p, left);
            if (w < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    struct pollfd pfds[2] = { { _fd, POLLOUT, 0 }, { _pipeCancel[0], POLLIN, 0 } };
                    poll(pfds, 2, _readTimeoutMs);
                    if (pfds[1].revents & POLLIN) {
                        RNSetError(error, RNErrorCancelled, @"Write cancelled");
                        return NO;
                    }
                    continue;
                }
                RNSetError(error, RNErrorNetwork, [NSString stringWithFormat:@"Write failed: %s", strerror(errno)]);
                return NO;
            }
            p += w;
            left -= w;
        } else {
            int ret = mbedtls_ssl_write(&_ssl, p, left);
            if (ret > 0) {
                p += ret;
                left -= ret;
                continue;
            }
            if (ret == MBEDTLS_ERR_SSL_WANT_WRITE || ret == MBEDTLS_ERR_SSL_WANT_READ) {
                struct pollfd pfds[2] = {
                    { _fd, (short)((ret == MBEDTLS_ERR_SSL_WANT_READ) ? POLLIN : POLLOUT), 0 },
                    { _pipeCancel[0], POLLIN, 0 }
                };
                poll(pfds, 2, _readTimeoutMs);
                if (pfds[1].revents & POLLIN) {
                    RNSetError(error, RNErrorCancelled, @"Write cancelled");
                    return NO;
                }
                continue;
            }
            RNSetError(error, RNErrorTLS, [NSString stringWithFormat:@"TLS write failed: %@", RNMbedError(ret)]);
            return NO;
        }
    }
    return YES;
}

- (NSInteger)readIntoBuffer:(void *)buffer maxLength:(NSUInteger)maxLength error:(NSError **)error
{
    if (!_connected) {
        RNSetError(error, RNErrorNetwork, @"Socket not connected");
        return -1;
    }
    while (YES) {
        if (_cancelled) {
            RNSetError(error, RNErrorCancelled, @"Read cancelled");
            return -1;
        }
        if (self.plain) {
            ssize_t r = read(_fd, buffer, maxLength);
            if (r > 0) return r;
            if (r == 0) return 0;
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                struct pollfd pfds[2] = { { _fd, POLLIN, 0 }, { _pipeCancel[0], POLLIN, 0 } };
                int pr = poll(pfds, 2, _readTimeoutMs);
                if (pr <= 0 || (pfds[1].revents & POLLIN)) {
                    RNSetError(error, _cancelled ? RNErrorCancelled : RNErrorTimeout,
                               _cancelled ? @"Read cancelled" : @"Read timed out");
                    return -1;
                }
                continue;
            }
            RNSetError(error, RNErrorNetwork, [NSString stringWithFormat:@"Read failed: %s", strerror(errno)]);
            return -1;
        } else {
            int ret = mbedtls_ssl_read(&_ssl, (unsigned char *)buffer, maxLength);
            if (ret > 0) return ret;
            if (ret == 0 || ret == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY) return 0;
            if (ret == MBEDTLS_ERR_SSL_WANT_READ || ret == MBEDTLS_ERR_SSL_WANT_WRITE) {
                struct pollfd pfds[2] = {
                    { _fd, (short)((ret == MBEDTLS_ERR_SSL_WANT_READ) ? POLLIN : POLLOUT), 0 },
                    { _pipeCancel[0], POLLIN, 0 }
                };
                int pr = poll(pfds, 2, _readTimeoutMs);
                if (pr <= 0 || (pfds[1].revents & POLLIN)) {
                    RNSetError(error, _cancelled ? RNErrorCancelled : RNErrorTimeout,
                               _cancelled ? @"Read cancelled" : @"Read timed out");
                    return -1;
                }
                continue;
            }
            RNSetError(error, RNErrorTLS, [NSString stringWithFormat:@"TLS read failed: %@", RNMbedError(ret)]);
            return -1;
        }
    }
}

- (NSString *)cipherSuite
{
    if (!_sslInited) return nil;
    const char *c = mbedtls_ssl_get_ciphersuite(&_ssl);
    return c ? [NSString stringWithUTF8String:c] : nil;
}

- (NSString *)tlsVersion
{
    if (!_sslInited) return nil;
    const char *v = mbedtls_ssl_get_version(&_ssl);
    return v ? [NSString stringWithUTF8String:v] : nil;
}

@end
