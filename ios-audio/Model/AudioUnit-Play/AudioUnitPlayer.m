//
//  AudioUnitPlayer.m
//  ios-audio
//
//  Created by mac on 2020/9/25.
//

#import "AudioUnitPlayer.h"

@interface AudioUnitPlayer(){
    ExtAudioFileRef audioFile;
    AudioStreamBasicDescription fileDesc;   //文件的ASBD
    AudioStreamBasicDescription clientDesc; //Application("Client")的ASBD
    AudioUnit audioUnit;
}

@end

@implementation AudioUnitPlayer

-(id)initWithAudio:(NSString *)path{
    [self configExtAudioFileReaderWithPath:path];
    
    [self configOutputOnlyAudioUnit];
    
    return self;
}

// 1. 配置扩展音频文件
-(void)configExtAudioFileReaderWithPath:(NSString *)path{
    //1. 获取 ExtAudioFileRef
    CFURLRef audioFileURL =(__bridge CFURLRef)[NSURL fileURLWithPath:path];
    OSStatus status = ExtAudioFileOpenURL(audioFileURL, &audioFile);
    checkOSStatus(status);
    CFRelease (audioFileURL);
    //2. 获取 AudioStreamBasicDescription
    UInt32 size = sizeof(fileDesc);
    status = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileDataFormat, &size, &fileDesc);
    checkOSStatus(status);
    //3. 设置客户端ASBD为PCM
    clientDesc.mSampleRate = fileDesc.mSampleRate;
    clientDesc.mFormatID = kAudioFormatLinearPCM;
    clientDesc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    clientDesc.mReserved = 0;
    clientDesc.mChannelsPerFrame = 1; //2
    clientDesc.mBitsPerChannel = 16;
    clientDesc.mFramesPerPacket = 1;
    clientDesc.mBytesPerFrame = clientDesc.mChannelsPerFrame * clientDesc.mBitsPerChannel / 8;
    clientDesc.mBytesPerPacket = clientDesc.mBytesPerFrame;
    //4. 设置APP的AudioStreamBasicDescription
    size = sizeof(clientDesc);
    status = ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat, size, &clientDesc);
    checkOSStatus(status);
}

// 2. 配置只有输出的Remote I/O Unit
-(void)configOutputOnlyAudioUnit{
    OSStatus status;
    // 0. Element0
    AudioUnitElement element0=0;
    // 1. 描述音频元件 - RemoteIO
    AudioComponentDescription aComponentDesc;
    aComponentDesc.componentType                      = kAudioUnitType_Output;
    aComponentDesc.componentSubType                   = kAudioUnitSubType_RemoteIO;
    aComponentDesc.componentManufacturer              = kAudioUnitManufacturer_Apple;
    aComponentDesc.componentFlags                     = 0;
    aComponentDesc.componentFlagsMask                 = 0;
    // 2. 获得一个音频元件
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &aComponentDesc);
    // 3. 获得 Audio Unit
    status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    checkOSStatus(status);
    // 4. 开启Element0的Output Scope
    UInt32 falg = 1;
    status = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, element0, &falg, sizeof(UInt32));
    checkOSStatus(status);
    // 5. 为Element0的Input Scope设置流格式
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  element0,
                                  &clientDesc,
                                  sizeof(clientDesc));
    checkOSStatus(status);
    // 6. 设置声音输出（Render）的回调函数
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = renderCallback;
    callbackStruct.inputProcRefCon = (__bridge_retained void * _Nullable)(self);
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Group,//kAudioUnitScope_Global,
                                  element0,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    
    checkOSStatus(status);
    // 7. 设置声音输出（Render）通知的回调函数
    status = AudioUnitAddRenderNotify(audioUnit,
                                      renderNotifyCallback,
                                      (__bridge_retained void * _Nullable)(self));
    checkOSStatus(status);
    // 8. 初始化AudioUnit
    status = AudioUnitInitialize(audioUnit);
    checkOSStatus(status);
}

// 3. 播放音频（Render）的回调函数
static OSStatus renderCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData) {
    //printAudioUnitRenderActionFlags(*ioActionFlags);
    //printAudioTimeStamp(inTimeStamp);
    //NSLog(@"Bus编号:%d,样本帧数:%d",inBusNumber,inNumberFrames);
    
    AudioUnitPlayer *auPlayer = (__bridge AudioUnitPlayer *)(inRefCon);
    UInt32 framesPerPacket = inNumberFrames;
    OSStatus status = [auPlayer readFrames:&framesPerPacket toBufferList:ioData];
    
    return status;
}

// 播放音频（Render）通知的回调函数
static OSStatus renderNotifyCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
    return noErr;
}

// 4. 从文件中读取音频帧到 AudioBufferList *ioData
-(OSStatus)readFrames:(UInt32 *)framesNum toBufferList:(AudioBufferList *)bufferList{
    if (audioFile == nil) {
        *framesNum = 0;
        return -1;
    }
    
    OSStatus status = ExtAudioFileRead(audioFile, framesNum, bufferList);
    checkOSStatus(status);
    
    return status;
}

#pragma mark - print info function

// 检测状态
void checkOSStatus(OSStatus status) {
    if(status!=0)
        printf("Error: %d\n", (int)status);
}

// 打印 AudioStreamBasicDescription
-(void)printASBD: (AudioStreamBasicDescription) asbd {
 
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig (asbd.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
 
    NSLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"  Format ID:           %10s",    formatIDString);
    NSLog (@"  Format Flags:        %10X",    (unsigned int)asbd.mFormatFlags);
    NSLog (@"  Bytes per Packet:    %10u",    (unsigned int)asbd.mBytesPerPacket);
    NSLog (@"  Frames per Packet:   %10u",    (unsigned int)asbd.mFramesPerPacket);
    NSLog (@"  Bytes per Frame:     %10u",    (unsigned int)asbd.mBytesPerFrame);
    NSLog (@"  Channels per Frame:  %10u",    (unsigned int)asbd.mChannelsPerFrame);
    NSLog (@"  Bits per Channel:    %10u",    (unsigned int)asbd.mBitsPerChannel);
}

// 打印 AudioUnitRenderActionFlags
void printAudioUnitRenderActionFlags(AudioUnitRenderActionFlags ioActionFlags){
    if (ioActionFlags==kAudioUnitRenderAction_PreRender){
        NSLog(@"在执行渲染操作之前");
    }else if (ioActionFlags==kAudioUnitRenderAction_PostRender){
        NSLog(@"在执行渲染操作之后");
    }else if (ioActionFlags==kAudioUnitRenderAction_OutputIsSilence){
        NSLog(@"无声");
    }else if (ioActionFlags==kAudioOfflineUnitRenderAction_Preflight){
        NSLog(@"在执行实际脱机渲染操作之前");
    }else if (ioActionFlags==kAudioOfflineUnitRenderAction_Render){
        NSLog(@"进入渲染模式");
    }else if (ioActionFlags==kAudioOfflineUnitRenderAction_Complete){
        NSLog(@"完成执行渲染操作");
    }else if (ioActionFlags==kAudioUnitRenderAction_PostRenderError){
        NSLog(@"错误");
    }else if (ioActionFlags==kAudioUnitRenderAction_DoNotCheckRenderArgs){
        NSLog(@"不会对提供给渲染的参数执行检查");
    }else{
        NSLog(@"%u",(unsigned int)ioActionFlags);
    }
}

// 打印 AudioTimeStamp
void printAudioTimeStamp(const AudioTimeStamp *audioTimeStamp){
    NSLog(@"Flags:%u,主机的时基:%llu，Rate比率:%f，样本帧时间:%f，世界时钟时间:%llu",(unsigned int)audioTimeStamp->mFlags,audioTimeStamp->mHostTime,audioTimeStamp->mRateScalar,audioTimeStamp->mSampleTime,audioTimeStamp->mWordClockTime);
    SMPTETime mSMPTETime=audioTimeStamp->mSMPTETime;
    NSLog(@"Type:%u，子帧数:%d [%d:%d:%d:%d]",(unsigned int)mSMPTETime.mType,mSMPTETime.mSubframeDivisor,mSMPTETime.mHours,mSMPTETime.mMinutes,mSMPTETime.mSeconds,mSMPTETime.mFrames);
}


#pragma mark - public function
//开启 Audio Unit
- (void)start {
    OSStatus status = AudioOutputUnitStart(audioUnit);
    checkOSStatus(status);
}


@end
