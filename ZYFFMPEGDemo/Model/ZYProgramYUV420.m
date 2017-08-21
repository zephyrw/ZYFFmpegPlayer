//
//  ZYProgramYUV420.m
//  ZYFFMPEGDemo
//
//  Created by wpsd on 2017/8/10.
//  Copyright © 2017年 wpsd. All rights reserved.
//

#import "ZYProgramYUV420.h"
#import "GLESUtils.h"
#import "ZYVideoFrame.h"

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

NSString *vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 textureCoord;
 uniform mat4 mvp_matrix;
 varying vec2 v_textureCoord;
 
 void main()
 {
     v_textureCoord = textureCoord;
     gl_Position = mvp_matrix * position;
 }
 );

NSString *fragmentShaderString = SHADER_STRING
(
 uniform sampler2D SamplerY;
 uniform sampler2D SamplerU;
 uniform sampler2D SamplerV;
 varying mediump vec2 v_textureCoord;
 
 void main()
 {
     highp float y = texture2D(SamplerY, v_textureCoord).r;
     highp float u = texture2D(SamplerU, v_textureCoord).r - 0.5;
     highp float v = texture2D(SamplerV, v_textureCoord).r - 0.5;
     
     highp float r = y +             1.402 * v;
     highp float g = y - 0.344 * u - 0.714 * v;
     highp float b = y + 1.772 * u;
     
     gl_FragColor = vec4(r , g, b, 1.0);
 }
 );

static GLKVector3 vertex_buffer_data[] = {
    {-1, 1, 0.0},
    {1, 1, 0.0},
    {1, -1, 0.0},
    {-1, -1, 0.0},
};

static GLushort index_buffer_data[] = {
    0, 1, 2, 0, 2, 3
};

static GLKVector2 texture_buffer_data_r0[] = {
    {0.0, 0.0},
    {1.0, 0.0},
    {1.0, 1.0},
    {0.0, 1.0},
};

static GLKVector2 texture_buffer_data_r90[] = {
    {0.0, 1.0},
    {0.0, 0.0},
    {1.0, 0.0},
    {1.0, 1.0},
};

static GLKVector2 texture_buffer_data_r180[] = {
    {1.0, 1.0},
    {0.0, 1.0},
    {0.0, 0.0},
    {1.0, 0.0},
};

static GLKVector2 texture_buffer_data_r270[] = {
    {1.0, 0.0},
    {1.0, 1.0},
    {0.0, 1.0},
    {0.0, 0.0},
};

static GLuint vertex_buffer_id = 0;
static GLuint index_buffer_id = 0;
static GLuint texture_buffer_id = 0;

static int const vertex_count = 4;

@interface ZYProgramYUV420()

@property (nonatomic, assign) GLint program_id;

@property (nonatomic, assign) GLint position_location;
@property (nonatomic, assign) GLint texture_coord_location;
@property (nonatomic, assign) GLint matrix_location;

@property (nonatomic, assign) GLint samplerY_location;
@property (nonatomic, assign) GLint samplerU_location;
@property (nonatomic, assign) GLint samplerV_location;

@end

@implementation ZYProgramYUV420

static GLuint gl_texture_ids[3];

+ (instancetype)program {
    
    ZYProgramYUV420 *program = [ZYProgramYUV420 new];
    
    program.program_id = [GLESUtils loadProgramWithVertexShaderString:vertexShaderString withFragmentShaderString:fragmentShaderString];
    [program setupVariable];
    [program bindVariable];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        glGenTextures(3, gl_texture_ids);
        glGenBuffers(1, &index_buffer_id);
        glGenBuffers(1, &vertex_buffer_id);
        glGenBuffers(1, &texture_buffer_id);
    });
    
    return program;
    
}

- (void)use {
    
    glUseProgram(_program_id);
    
}

- (void)updateMatrix:(GLKMatrix4)matrix
{
    glUniformMatrix4fv(self.matrix_location, 1, GL_FALSE, matrix.m);
}

- (void)bindVariable
{
    glEnableVertexAttribArray(self.position_location);
    glEnableVertexAttribArray(self.texture_coord_location);
    
    glUniform1i(self.samplerY_location, 0);
    glUniform1i(self.samplerU_location, 1);
    glUniform1i(self.samplerV_location, 2);
}

- (void)setupVariable
{
    self.position_location = glGetAttribLocation(self.program_id, "position");
    self.texture_coord_location = glGetAttribLocation(self.program_id, "textureCoord");
    self.matrix_location = glGetUniformLocation(self.program_id, "mvp_matrix");
    self.samplerY_location = glGetUniformLocation(self.program_id, "SamplerY");
    self.samplerU_location = glGetUniformLocation(self.program_id, "SamplerU");
    self.samplerV_location = glGetUniformLocation(self.program_id, "SamplerV");
}

- (BOOL)updateTextureWithGLFrame:(ZYVideoFrame *)videoFrame aspect:(CGFloat *)aspect
{
    
    if (!videoFrame) {
        return NO;
    }
    
    const int frameWidth = videoFrame.width;
    const int frameHeight = videoFrame.height;
    * aspect = (frameWidth * 1.0) / (frameHeight * 1.0);
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    const int widths[3]  = {
        frameWidth,
        frameWidth / 2,
        frameWidth / 2
    };
    const int heights[3] = {
        frameHeight,
        frameHeight / 2,
        frameHeight / 2
    };
    
    for (SGYUVChannel channel = SGYUVChannelLuma; channel < SGYUVChannelCount; channel++)
    {
        glActiveTexture(GL_TEXTURE0 + channel);
        glBindTexture(GL_TEXTURE_2D, gl_texture_ids[channel]);
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_LUMINANCE,
                     widths[channel],
                     heights[channel],
                     0,
                     GL_LUMINANCE,
                     GL_UNSIGNED_BYTE,
                     videoFrame->channel_pixels[channel]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    
    return YES;
}

- (void)bindBuffer {
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, index_buffer_id);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, index_count * sizeof(GLshort), index_buffer_data, GL_STATIC_DRAW);
    
    glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer_id);
    glBufferData(GL_ARRAY_BUFFER, vertex_count * 3 * sizeof(GLfloat), vertex_buffer_data, GL_STATIC_DRAW);
    glEnableVertexAttribArray(_position_location);
    glVertexAttribPointer(_position_location, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), NULL);
    
    glBindBuffer(GL_ARRAY_BUFFER, texture_buffer_id);
    glBufferData(GL_ARRAY_BUFFER, vertex_count * 2 * sizeof(GLfloat), texture_buffer_data_r0, GL_STATIC_DRAW);
    glEnableVertexAttribArray(_texture_coord_location);
    glVertexAttribPointer(_texture_coord_location, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), NULL);
    
}

- (void)clearProgram
{
    if (_program_id) {
        glDeleteProgram(_program_id);
        _program_id = 0;
    }
}

- (void)dealloc
{
    [self clearProgram];
    NSLog(@"%@ release", self.class);
}

@end
