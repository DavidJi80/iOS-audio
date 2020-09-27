//
//  ViewController.m
//  ios-audio
//
//  Created by mac on 2020/9/19.
//

#import "ViewController.h"
#import "AQSPlayViewController.h"
#import "AudioController.h"
#import "AQSAudioPlayer.h"

@interface ViewController ()

@property (strong, nonatomic) UIButton *aqsPlayBtn;
@property (strong, nonatomic) UIButton *aqsPlayAudioBtn;
@property (strong, nonatomic) UIButton *audioUnitPlayBtn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configBaseUI];
}

#pragma mark - BaseSet
- (void)configBaseUI{
    [self.view addSubview:self.aqsPlayBtn];
    [self.aqsPlayBtn makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(80);
        make.left.equalTo(self.view).offset(10);
        make.right.equalTo(self.view).offset(-10);
        make.height.equalTo(40);
    }];
    
    [self.view addSubview:self.aqsPlayAudioBtn];
    [self.aqsPlayAudioBtn makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.aqsPlayBtn.bottom).offset(10);
        make.left.width.height.equalTo(self.aqsPlayBtn);
    }];
    
    [self.view addSubview:self.audioUnitPlayBtn];
    [self.audioUnitPlayBtn makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.aqsPlayAudioBtn.bottom).offset(10);
        make.left.width.height.equalTo(self.aqsPlayBtn);
    }];
}

- (UIButton *)aqsPlayBtn{
    if (!_aqsPlayBtn) {
        UIButton *button = [[UIButton alloc]init];
        [button setBackgroundImage:nil forState:UIControlStateNormal];
        [button setTitle:@"Audio Queue Services - Play Audio" forState:UIControlStateNormal];
        [button addTarget:self action:@selector(aqsPlay) forControlEvents:UIControlEventTouchUpInside];
        button.backgroundColor=UIColor.brownColor;
        _aqsPlayBtn = button;
    }
    return _aqsPlayBtn;
}

- (UIButton *)aqsPlayAudioBtn{
    if (!_aqsPlayAudioBtn) {
        UIButton *button = [[UIButton alloc]init];
        [button setBackgroundImage:nil forState:UIControlStateNormal];
        [button setTitle:@"Audio Queue Services - Audio Player" forState:UIControlStateNormal];
        [button addTarget:self action:@selector(aqsPlayAudio) forControlEvents:UIControlEventTouchUpInside];
        button.backgroundColor=UIColor.brownColor;
        _aqsPlayAudioBtn = button;
    }
    return _aqsPlayAudioBtn;
}

- (UIButton *)audioUnitPlayBtn{
    if (!_audioUnitPlayBtn) {
        UIButton *button = [[UIButton alloc]init];
        [button setBackgroundImage:nil forState:UIControlStateNormal];
        [button setTitle:@"Audio Unit - Play Audio" forState:UIControlStateNormal];
        [button addTarget:self action:@selector(audioUnitPlay) forControlEvents:UIControlEventTouchUpInside];
        button.backgroundColor=UIColor.brownColor;
        _audioUnitPlayBtn = button;
    }
    return _audioUnitPlayBtn;
}

-(void)aqsPlay{
    AQSPlayViewController *vc=[AQSPlayViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

-(void)aqsPlayAudio{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"1" ofType:@"mp3"];
    
    AQSAudioPlayer *audio= [[AQSAudioPlayer alloc]initWithAudio:path];
}

-(void)audioUnitPlay{
    AudioController *audioController=[AudioController sharedAudioManager];
    [audioController start];
}


@end
