#include <stdlib.h>
// Mini GPU test: EGL surfaceless + GLES2, draws N frames into an FBO and reads pixels back.
// Build: cc -O2 gltest.c -o gltest -lEGL -lGLESv2   Run: ./gltest 500
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <stdio.h>
#include <time.h>
static const char *vs = "attribute vec2 p; uniform float t; void main(){ float a=t+p.x*6.28; gl_Position=vec4(cos(a)*p.y, sin(a)*p.y, 0.0, 1.0);}";
static const char *fs = "precision highp float; uniform float t; void main(){ gl_FragColor=vec4(fract(t),0.5,0.25,1.0);}";
int main(int argc, char **argv) {
  int frames = argc > 1 ? atoi(argv[1]) : 500;
  PFNEGLGETPLATFORMDISPLAYEXTPROC gpd = (void*)eglGetProcAddress("eglGetPlatformDisplayEXT");
  EGLDisplay d = gpd(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, NULL);
  if (!eglInitialize(d, NULL, NULL)) { puts("eglInitialize failed"); return 1; }
  eglBindAPI(EGL_OPENGL_ES_API);
  EGLint ca[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
  EGLContext c = eglCreateContext(d, EGL_NO_CONFIG_KHR, EGL_NO_CONTEXT, ca);
  eglMakeCurrent(d, EGL_NO_SURFACE, EGL_NO_SURFACE, c);
  printf("Renderer: %s\n", glGetString(GL_RENDERER));
  GLuint tex, fbo; glGenTextures(1, &tex); glBindTexture(GL_TEXTURE_2D, tex);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1920, 1080, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
  glGenFramebuffers(1, &fbo); glBindFramebuffer(GL_FRAMEBUFFER, fbo);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
  GLuint s1 = glCreateShader(GL_VERTEX_SHADER), s2 = glCreateShader(GL_FRAGMENT_SHADER), pr = glCreateProgram();
  glShaderSource(s1, 1, &vs, NULL); glCompileShader(s1); glShaderSource(s2, 1, &fs, NULL); glCompileShader(s2);
  glAttachShader(pr, s1); glAttachShader(pr, s2); glBindAttribLocation(pr, 0, "p"); glLinkProgram(pr);
  { GLint ok; char log[512]; glGetShaderiv(s1, GL_COMPILE_STATUS, &ok); if(!ok){glGetShaderInfoLog(s1,512,NULL,log);printf("VS: %s\n",log);}
    glGetShaderiv(s2, GL_COMPILE_STATUS, &ok); if(!ok){glGetShaderInfoLog(s2,512,NULL,log);printf("FS: %s\n",log);}
    glGetProgramiv(pr, GL_LINK_STATUS, &ok); if(!ok){glGetProgramInfoLog(pr,512,NULL,log);printf("Link: %s\n",log);}
    printf("FBO: 0x%x\n", glCheckFramebufferStatus(GL_FRAMEBUFFER)); }
  glUseProgram(pr);
  enum { N = 30000 }; static float v[N * 2];
  for (int i = 0; i < N; i++) { v[2*i] = (float)i / N; v[2*i+1] = 0.2f + 0.8f * ((i * 7919) % 1000) / 1000.0f; }
  glEnableVertexAttribArray(0); glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, v);
  GLint ut = glGetUniformLocation(pr, "t"); glViewport(0, 0, 1920, 1080);
  struct timespec a, b; clock_gettime(CLOCK_MONOTONIC, &a);
  unsigned char px[4];
  for (int f = 0; f < frames; f++) {
    glClearColor(0, 0, 0, 1); glClear(GL_COLOR_BUFFER_BIT);
    glUniform1f(ut, f * 0.01f); glDrawArrays(GL_TRIANGLES, 0, N);
  }
  glReadPixels(960, 540, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
  static unsigned char img[1920*1080*4]; glReadPixels(0, 0, 1920, 1080, GL_RGBA, GL_UNSIGNED_BYTE, img);
  unsigned long nonblack = 0, sum = 0; for (long i = 0; i < 1920L*1080; i++) { if (img[4*i]|img[4*i+1]|img[4*i+2]) nonblack++; sum += img[4*i]+img[4*i+1]+img[4*i+2]; }
  printf("colored pixels: %lu, sum: %lu\n", nonblack, sum);
  clock_gettime(CLOCK_MONOTONIC, &b);
  double s = (b.tv_sec - a.tv_sec) + (b.tv_nsec - a.tv_nsec) / 1e9;
  printf("%d frames 1920x1080 in %.2f s = %.0f fps, Pixel = %d %d %d %d, glGetError = 0x%x\n", frames, s, frames / s, px[0], px[1], px[2], px[3], glGetError());
  return 0;
}
