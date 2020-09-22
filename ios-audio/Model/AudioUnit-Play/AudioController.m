//
//  AudioController.m
//  ios-audio
//
//  Created by mac on 2020/9/22.
//

#import "AudioController.h"
#import <AVFoundation/AVFoundation.h>

static void checkStatus(OSStatus status);

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
    
    return self;
}

static void checkStatus(OSStatus status){
    
}

static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    return noErr;
}

@end
