//
//  AudioController.m
//  ios-audio
//
//  Created by mac on 2020/9/22.
//

#import "AudioController.h"
#import <AVFoundation/AVFoundation.h>

//static void checkStatus(OSStatus status);

@interface AudioController() {
    AudioStreamBasicDescription audioFormat;
}

@property (nonatomic, assign) AudioUnit rioUnit;
@property (nonatomic, assign) AudioBufferList bufferList;

@end

@implementation AudioController

+ (AudioController *)sharedAudioManager {
    static AudioController *sharedAudioManager;
    @synchronized(self) {
        if (!sharedAudioManager) {
            sharedAudioManager = [[AudioController alloc] init];
        }
        return sharedAudioManager;
    }
}

#define kOutputBus 0
#define kInputBus 1
// Bus 0 is used for the output side, bus 1 is used to get audio input.

- (id)init {
    
    OSStatus status;
    AudioComponentInstance audioUnit;
    
    // Describe audio component
    // 描述音频元件
    AudioComponentDescription desc;
    desc.componentType                      = kAudioUnitType_Output;
    desc.componentSubType                   = kAudioUnitSubType_RemoteIO;
    desc.componentFlags                     = 0;
    desc.componentFlagsMask                 = 0;
    desc.componentManufacturer              = kAudioUnitManufacturer_Apple;
    
    // Get component
    // 获得一个元件
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
    
    // Get audio units
    // 获得 Audio Unit
    status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    checkStatus(status);
    
    // Enable IO for recording
    // 为录制打开 IO
    UInt32 flag = 1;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  kInputBus,
                                  &flag,
                                  sizeof(flag));
    checkStatus(status);
    
    // Enable IO for playback
    // 为播放打开 IO
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  kOutputBus,
                                  &flag,
                                  sizeof(flag));
    checkStatus(status);
    
    // Describe format
    // 描述格式
    audioFormat.mSampleRate                 = 44100.00;
    audioFormat.mFormatID                   = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags                = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket            = 1;
    audioFormat.mChannelsPerFrame           = 1;
    audioFormat.mBitsPerChannel             = 16;
    audioFormat.mBytesPerPacket             = 2;
    audioFormat.mBytesPerFrame              = 2;
    
    // Apply format
    // 设置格式
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &audioFormat,
                                  sizeof(audioFormat));
    checkStatus(status);
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &audioFormat,
                                  sizeof(audioFormat));
    checkStatus(status);
    
    
    // Set input callback
    // 设置数据采集回调函数
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = recordingCallback;
    callbackStruct.inputProcRefCon = (__bridge void * _Nullable)(self);
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global,
                                  kInputBus,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    checkStatus(status);
    
    // Set output callback
    // 设置声音输出回调函数。当speaker需要数据时就会调用回调函数去获取数据。它是 "拉" 数据的概念。
    callbackStruct.inputProc = playbackCallback;
    callbackStruct.inputProcRefCon = (__bridge void * _Nullable)(self);
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  kOutputBus,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    checkStatus(status);
    
    // Disable buffer allocation for the recorder (optional - do this if we want to pass in our own)
    // 关闭为录制分配的缓冲区（我们想使用我们自己分配的）
    flag = 0;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_ShouldAllocateBuffer,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &flag,
                                  sizeof(flag));
    
    //Allocate our own buffers if we want
    
    // Initialise
    // 初始化
    status = AudioUnitInitialize(audioUnit);
    checkStatus(status);
//    //Initialise也可以用以下代码
//    UInt32 category = kAudioSessionCategory_PlayAndRecord;
//    status = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
//    checkStatus(status);
//    status = 0;
//    status = AudioSessionSetActive(YES);
//    checkStatus(status);
//    status = AudioUnitInitialize(_rioUnit);
//    checkStatus(status);
    
    _rioUnit=audioUnit;
    
    return self;
}

// 检测状态
void checkStatus(OSStatus status) {
    if(status!=0)
        printf("Error: %d\n", (int)status);
}

static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    NSLog(@"[recording] Bus编号:%d,样本帧数:%d",inBusNumber,inNumberFrames);
    
    
    // TODO:
    // 使用 inNumberFrames 计算有多少数据是有效的
    // 在 AudioBufferList 里存放着更多的有效空间
    
    AudioController *THIS = (__bridge AudioController*) inRefCon;
    //bufferList里存放着一堆 buffers, buffers的长度是动态的。
    THIS->_bufferList.mNumberBuffers = 1;
    THIS->_bufferList.mBuffers[0].mDataByteSize = sizeof(SInt16)*inNumberFrames;
    THIS->_bufferList.mBuffers[0].mNumberChannels = 1;
    THIS->_bufferList.mBuffers[0].mData = (SInt16*) malloc(sizeof(SInt16)*inNumberFrames);
    
    // 获得录制的采样数据
    OSStatus status;
    status = AudioUnitRender(THIS->_rioUnit,
                             ioActionFlags,
                             inTimeStamp,
                             inBusNumber,
                             inNumberFrames,
                             &(THIS->_bufferList));
    checkStatus(status);
    
    // 现在，我们想要的采样数据已经在bufferList中的buffers中了。
//    DoStuffWithTheRecordedAudio(bufferList);
    return noErr;
}

static OSStatus playbackCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
    NSLog(@"[play] Bus编号:%d,样本帧数:%d",inBusNumber,inNumberFrames);
    return noErr;
}

//开启 Audio Unit
- (void)start {
    OSStatus status = AudioOutputUnitStart(_rioUnit);
    checkStatus(status);
}

//关闭 Audio Unit
- (void)stop {
    OSStatus status = AudioOutputUnitStop(_rioUnit);
    checkStatus(status);
}

//结束 Audio Unit
- (void)finished {
    AudioComponentInstanceDispose(_rioUnit);
}

@end
