//
//  AudioUnitPlayer.m
//  ios-audio
//
//  Created by mac on 2020/9/25.
//

#import "AudioUnitPlayer.h"

@implementation AudioUnitPlayer

// 播放音频队列回调
static OSStatus renderCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData) {
    NSLog(@"inBusNumber:%u,inNumberFrames:%u",(unsigned int)inBusNumber,(unsigned int)inNumberFrames);
    AudioUnitPlayer *auPlayer = (__bridge AudioUnitPlayer *)(inRefCon);        // 1
//    UInt32 numBytesReadFromFile;                              // 3
//    UInt32 numPackets;           // 4
//    OSStatus status=AudioFileReadPacketData(                            // 1
//                                            auPlayer->mAudioFile,        // 2
//                            false,                      // 3
//                            &numBytesReadFromFile,      // 4
//                                            auPlayer->mPacketDescs,      // 5
//                                            auPlayer->mCurrentPacket,    // 6
//                            &numPackets,                // 7
//                            inBuffer->mAudioData        // 8
//                            );
    return noErr;
}

-(id)initWithAudio:(NSString *)path{
    //1.1
    CFURLRef audioFileURL =(__bridge CFURLRef)[NSURL fileURLWithPath:path];
    
    //1.2
    OSStatus status=AudioFileOpenURL(                           // 2
                                     audioFileURL,              // 3
                                     kAudioFileReadPermission,  // 4
                                     0,                         // 5
                                     &mAudioFile                // 6
                                     );
    checkOSStatus(status);
    CFRelease (audioFileURL);                                   // 7
    //1.3
    UInt32 dataFormatSize = sizeof (mDataFormat);           // 1
    AudioFileGetProperty (                                  // 2
        mAudioFile,                                         // 3
        kAudioFilePropertyDataFormat,                       // 4
        &dataFormatSize,                                    // 5
        &mDataFormat                                        // 6
    );
    [self printASBD:mDataFormat];
    
    /* Audio Unit Hosting */
    
    // 描述音频元件 - RemoteIO
    AudioComponentDescription aComponentDesc;
    aComponentDesc.componentType                      = kAudioUnitType_Output;
    aComponentDesc.componentSubType                   = kAudioUnitSubType_RemoteIO;
    aComponentDesc.componentManufacturer              = kAudioUnitManufacturer_Apple;
    aComponentDesc.componentFlags                     = 0;
    aComponentDesc.componentFlagsMask                 = 0;
    UInt32 comCount=AudioComponentCount(&aComponentDesc);
    NSLog(@"共有 %d RemoteIO",comCount);
    // 获得一个元件
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &aComponentDesc);

    // 获得 Audio Unit
    //AudioComponentInstance audioUnit;
    AudioUnit audioUnit;
    status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    checkOSStatus(status);
    
    UInt32 enableOutput        = 0;    // to disable output
    AudioUnitElement outputBus = 0;
    Boolean outWritable;
    status = AudioUnitGetPropertyInfo(
                                  audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  outputBus,
                                  &enableOutput,
                                      &outputBus);
    checkOSStatus(status);
    if (outWritable){
        NSLog(@"dd");
    }
//    NSLog(@"ElementCount:%d,%d",elementCount,elementCountSize);
    
//    AudioStreamBasicDescription audioFormat;
//    status = AudioUnitGetProperty(audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Global, 0, &elementCount, &elementCountSize);
//    checkOSStatus(status);
    

    return self;
}

// 检测状态
void checkOSStatus(OSStatus status) {
    if(status!=0)
        printf("Error: %d\n", (int)status);
}

- (void) printASBD: (AudioStreamBasicDescription) asbd {
 
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


@end
