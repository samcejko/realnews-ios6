#import "RNAppearanceViewController.h"
#import "RNCommon.h"

static NSString *const kRNThemeKey = @"rn_reader_theme";
static NSString *const kRNFontFamilyKey = @"rn_font_family";
static NSString *const kRNFontSizeKey = @"rn_font_size";

@interface RNAppearanceViewController () {
    UITableView *_tableView;
    NSArray *_fontNames;
    NSArray *_fontDisplayNames;
    UILabel *_sizeLabel;
}
@end

@implementation RNAppearanceViewController

+ (RNReaderTheme)currentTheme
{
    NSNumber *val = [[NSUserDefaults standardUserDefaults] objectForKey:kRNThemeKey];
    if (!val) return RNReaderThemeDay;
    return (RNReaderTheme)[val integerValue];
}

+ (void)setCurrentTheme:(RNReaderTheme)theme
{
    [[NSUserDefaults standardUserDefaults] setInteger:theme forKey:kRNThemeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)themeNameForTheme:(RNReaderTheme)theme
{
    switch (theme) {
        case RNReaderThemeSepia: return @"sepia";
        case RNReaderThemeNight: return @"night";
        case RNReaderThemeDay:
        default:
            return @"day";
    }
}

+ (NSString *)currentFontFamily
{
    NSString *f = [[NSUserDefaults standardUserDefaults] stringForKey:kRNFontFamilyKey];
    if (f.length) return f;
    return @"Georgia, serif";
}

+ (void)setCurrentFontFamily:(NSString *)fontFamily
{
    [[NSUserDefaults standardUserDefaults] setObject:fontFamily forKey:kRNFontFamilyKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSInteger)currentFontSize
{
    NSInteger s = [[NSUserDefaults standardUserDefaults] integerForKey:kRNFontSizeKey];
    if (s >= 12 && s <= 28) return s;
    return 16;
}

+ (void)setCurrentFontSize:(NSInteger)size
{
    if (size < 12) size = 12;
    if (size > 28) size = 28;
    [[NSUserDefaults standardUserDefaults] setInteger:size forKey:kRNFontSizeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.title = @"Vzhled";
        _fontNames = @[
            @"Georgia, serif",
            @"Palatino, serif",
            @"'Helvetica Neue', Helvetica, sans-serif",
            @"Baskerville, serif",
            @"'Trebuchet MS', sans-serif"
        ];
        _fontDisplayNames = @[
            @"Georgia",
            @"Palatino",
            @"Helvetica Neue",
            @"Baskerville",
            @"Trebuchet MS"
        ];
        self.contentSizeForViewInPopover = CGSizeMake(320, 380);
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (RNIsPad()) return YES;
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (RNIsPad()) return UIInterfaceOrientationMaskAll;
    return UIInterfaceOrientationMaskAll & ~UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:L(@"Done")
                                                                                  style:UIBarButtonItemStyleDone
                                                                                 target:self
                                                                                 action:@selector(doneTapped)];
    }

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundView = nil;
    _tableView.backgroundColor = RetroGroupedBackground();
    [self.view addSubview:_tableView];
}

- (void)doneTapped
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 1; // Theme selector
    if (section == 1) return 1; // Font size stepper
    if (section == 2) return _fontNames.count; // Font families
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return RetroSectionHeader([self tableView:tableView titleForHeaderInSection:section], tableView.bounds.size.width);
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [self tableView:tableView titleForHeaderInSection:section].length ? 32.0 : 10.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) return @"Motiv";
    if (section == 1) return @"Velikost písma";
    if (section == 2) return @"Písmo";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ThemeCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[ @"Den", @"Sépie", @"Noc" ]];
        seg.frame = CGRectMake(12, 6, cell.contentView.bounds.size.width - 24, 32);
        seg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        seg.segmentedControlStyle = UISegmentedControlStyleBar;
        seg.selectedSegmentIndex = [RNAppearanceViewController currentTheme];
        [seg addTarget:self action:@selector(themeChanged:) forControlEvents:UIControlEventValueChanged];
        [cell.contentView addSubview:seg];
        return cell;
    }

    if (indexPath.section == 1) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SizeCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        UIButton *minusBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        minusBtn.frame = CGRectMake(15, 6, 60, 32);
        [minusBtn setTitle:@"A-" forState:UIControlStateNormal];
        minusBtn.titleLabel.font = [UIFont systemFontOfSize:15.0f];
        [minusBtn addTarget:self action:@selector(decreaseFontSize) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:minusBtn];

        _sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(85, 6, cell.contentView.bounds.size.width - 170, 32)];
        _sizeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _sizeLabel.backgroundColor = [UIColor clearColor];
        _sizeLabel.textAlignment = UITextAlignmentCenter;
        _sizeLabel.font = [UIFont boldSystemFontOfSize:15.0f];
        _sizeLabel.text = [NSString stringWithFormat:@"%d pt", (int)[RNAppearanceViewController currentFontSize]];
        [cell.contentView addSubview:_sizeLabel];

        UIButton *plusBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        plusBtn.frame = CGRectMake(cell.contentView.bounds.size.width - 75, 6, 60, 32);
        plusBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [plusBtn setTitle:@"A+" forState:UIControlStateNormal];
        plusBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        [plusBtn addTarget:self action:@selector(increaseFontSize) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:plusBtn];

        return cell;
    }

    if (indexPath.section == 2) {
        static NSString *FontCellID = @"FontCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:FontCellID];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:FontCellID];
        }

        NSString *font = [_fontNames objectAtIndex:indexPath.row];
        NSString *disp = [_fontDisplayNames objectAtIndex:indexPath.row];
        cell.textLabel.text = disp;

        // Apply font preview to label if system supports it
        if ([disp isEqualToString:@"Georgia"]) cell.textLabel.font = [UIFont fontWithName:@"Georgia" size:16.0f];
        else if ([disp isEqualToString:@"Palatino"]) cell.textLabel.font = [UIFont fontWithName:@"Palatino-Roman" size:16.0f];
        else if ([disp isEqualToString:@"Helvetica Neue"]) cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:16.0f];
        else if ([disp isEqualToString:@"Baskerville"]) cell.textLabel.font = [UIFont fontWithName:@"Baskerville" size:16.0f];
        else if ([disp isEqualToString:@"Trebuchet MS"]) cell.textLabel.font = [UIFont fontWithName:@"TrebuchetMS" size:16.0f];

        NSString *current = [RNAppearanceViewController currentFontFamily];
        cell.accessoryType = [current isEqualToString:font] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

        return cell;
    }

    return [[UITableViewCell alloc] init];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 2) {
        NSString *selected = [_fontNames objectAtIndex:indexPath.row];
        [RNAppearanceViewController setCurrentFontFamily:selected];
        [_tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationNone];

        if ([self.delegate respondsToSelector:@selector(appearanceController:didChangeFontFamily:)]) {
            [self.delegate appearanceController:self didChangeFontFamily:selected];
        }
    }
}

#pragma mark - Actions

- (void)themeChanged:(UISegmentedControl *)sender
{
    RNReaderTheme theme = (RNReaderTheme)sender.selectedSegmentIndex;
    [RNAppearanceViewController setCurrentTheme:theme];

    if ([self.delegate respondsToSelector:@selector(appearanceController:didChangeTheme:)]) {
        [self.delegate appearanceController:self didChangeTheme:theme];
    }
}

- (void)decreaseFontSize
{
    NSInteger size = [RNAppearanceViewController currentFontSize] - 2;
    if (size < 12) size = 12;
    [RNAppearanceViewController setCurrentFontSize:size];
    _sizeLabel.text = [NSString stringWithFormat:@"%d pt", (int)size];

    if ([self.delegate respondsToSelector:@selector(appearanceController:didChangeFontSize:)]) {
        [self.delegate appearanceController:self didChangeFontSize:size];
    }
}

- (void)increaseFontSize
{
    NSInteger size = [RNAppearanceViewController currentFontSize] + 2;
    if (size > 28) size = 28;
    [RNAppearanceViewController setCurrentFontSize:size];
    _sizeLabel.text = [NSString stringWithFormat:@"%d pt", (int)size];

    if ([self.delegate respondsToSelector:@selector(appearanceController:didChangeFontSize:)]) {
        [self.delegate appearanceController:self didChangeFontSize:size];
    }
}

@end
