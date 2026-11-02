# 웹 최적화 측정과 한계

## 결과

| 항목 | 기존 측정 | 최적화 후 측정 |
| --- | ---: | ---: |
| 게시 파일 전체 | 539,056,127 bytes | 460,948,624 bytes |
| index.pck | 497,154,460 bytes | 약 419 MB (정확값은 docs/web-size-report.json) |
| index.wasm | 39,514,754 bytes | 39,514,754 bytes |
| gzip 예상 전송량 | docs/baseline-size-report.json | 427,987,346 bytes |
| 브라우저 최초 접속 실제 전송량 | 미측정 | 미측정 |

게시 크기 감소는 **78,107,503 bytes, 약 14.49%**다. MB는 1,000,000바이트 기준이다. 100MB 및 50MB 목표는 달성하지 못했다. 다운로드를 분할했다는 이유로 최초 다운로드가 줄었다고 계산하지 않았다. 현재 게임은 시작 전에 전체 PCK를 받는다. 실제 HTTP 전송량은 서버의 Content-Encoding·브라우저 캐시·재시도에 따라 달라지므로 gzip 추정값을 실측으로 주장하지 않는다.

이전 배포 폴더에는 원본 바이너리, Git 업로드용 분할 파일, `_site` 복원본이 중복되어 있다. 폴더 전체 크기와 실제 게시 파일 크기를 구분해 docs/baseline-size-report.json에 기록했다. 새 사이트에는 한 버전의 산출물만 포함된다.

## 실제 프로젝트 조사

원본: `../Topofyeon/project.godot`. 배포용 실제 작업 복사본: 이 저장소의 `project.godot`. 별도 가짜 프로젝트를 만들지 않았다. 원본 origin은 GBgenAI/TopOfYeon이며 변경하지 않았다. 대상은 최초 확인 당시 비어 있던 juyounginpark/FlowerOfYeon이고 기본 브랜치는 main이다. 기존 Actions는 없었다.

Godot 버전은 설치된 공식 **4.7.2 stable**이며 프로젝트 features는 4.7이다. GDScript를 사용하고 C#/모델 파일/GDExtension은 발견되지 않았다. 시작 씬은 `scenes/gametitle/GameTitleAnimated.tscn`. 기존 Autoload는 GameAudio와 BgmPlayer이고 Analytics를 추가했다. 루트 project.godot에 웹 전용 Compatibility를 사용하며 데스크톱 Forward+ 설정은 유지한다. 1280×720 화면이다.

씬은 타이틀, opening, menu, main, ending, fan_emperor, fan_sky의 7개다. 공통 scripts/grid_stage/world.gd가 연습맵 1~3, 본편 4~12를 구성한다. 아트는 art/* 및 stages/*, 오디오는 music/*.mp3 39개(약 24.8 MB), 셰이더는 shaders/*와 scripts 하위 .gdshader에 있다. 원본 이미지 합계는 약 685 MB다. 이미지 원본은 PNG 중심이며 폰트 3개를 포함한다. 원본 상위 30개 및 정확 중복 그룹은 [조사 결과](docs/resource-audit.json)에 있다.

최종 PCK에 실제 저장한 임포트 리소스 상위 30개는 [별도 목록](docs/largest-packed-resources.json)에 있다. 소스 PDF/ZIP/제작 참고 이미지는 큰 파일이어도 게임 패키지에는 포함되지 않을 수 있다. 원본 최대 개별 파일은 약 18.1MB이며 100MiB 초과 파일은 없다.

## 적용한 최적화

`tools/web_pipeline.py prepare`가 모든 게임 스크립트·씬·셰이더의 리소스 리터럴을 조사한다. 직접 참조는 보존하고, 문자열 연결/숫자 프레임 경로/JSON 데이터가 있는 디렉터리는 통째로 보존한다. 정적으로 참조되지 않은 이미지 45개(원본 약 78.5MB)와 하이라이트 캡처를 웹 export에서만 제외한다. 전체 제외 목록은 audit JSON에 기록한다. art/music/stages/scenes/shaders 원본의 누락·변경이 없는지 원본 작업 트리와 바이트 비교했다. 정적 추론에는 한계가 있으므로 새 동적 경로를 추가하면 필터와 참조 검사를 함께 확인해야 한다.

텍스처 크기·alpha·색상·품질·폰트·샘플레이트는 변경하지 않았다. 이미 압축된 MP3 음원을 다시 손실 압축하지 않았다. 무압축 WAV는 없었다. 픽셀 아트와 UI 가독성을 해칠 수 있는 일괄 리사이즈/VRAM 손실 압축은 적용하지 않았다. 정확 중복이 있어도 기존 경로와 JSON 참조를 보존하기 위해 원본 삭제·무리한 경로 통합은 하지 않았다.

공식 버전 일치 Web 템플릿으로 release export한다. thread_support=false, extensions_support=false, PWA=false, 별도 COOP/COEP 요구=false이다. JSON 런타임 데이터는 export include_filter로 보존한다. 공식 문서상 Godot 4 웹은 WebGL 2.0 Compatibility만 지원한다. screen texture 셰이더가 있어 렌더링의 동일성을 정적 검사로 보증할 수 없다. GPU/실제 브라우저 게임을 실행하지 않았으며 모바일 호환성도 주장하지 않는다.

## 지연 로딩을 적용하지 않은 이유

스테이지 코드는 월드의 preload 그래프, 공용 아트, 책 넘기기 스크린샷 합성, 화면 깊이 분할 카메라를 공유한다. 단순히 파일을 나눠도 이 참조 그래프가 초기 로드를 요구하므로 다운로드가 줄지 않는다. 안전한 지연 PCK는 각 preload의 런타임 경계, 폰트/공용 아트 분리, 다운로드 실패·재시도 UI와 모든 스테이지 검증이 필요하다. 게임 실행 없이 안전성을 입증할 수 없어 적용하지 않았다.

100MB 미만을 원한다면 다음 작업은 스테이지별 동적 로드 경계 설계와 공용 텍스처의 선택적 경량화다. 큰 스프라이트 시트의 실제 표시 크기·투명 여백을 실기에서 조사하고 선택한 원본에 한해 변환 품질을 비교해야 한다. 지금 구현은 플레이 기능·물리·컷 상태·연출을 바꾸지 않고 가능한 보수적 절감에 한정한다.

## 검증 범위

dummy 드라이버 에디터 임포트 및 release export 성공. Analytics.gd는 지정된 --check-only 방식으로 구문 검사 성공. export/import 로그의 SCRIPT ERROR/Parse Error/Compile Error/ERROR 없음. Node의 분석 코드 테스트 3개, Python 참조 테스트 2개, Actions YAML 구조/권한 검사, `/FlowerOfYeon/` 하위 경로 HTTP HEAD 10개 URL과 WASM MIME 검사 통과. HTTP 검사는 게임이나 WASM을 실행하지 않는다.

브라우저 콘솔·실제 WebAssembly 초기화·첫 스테이지·시각적 동일성·모바일·실제 전송량·실제 GA4 수신은 미검증이다. GA4 ID가 아직 없으므로 서버 수신을 검증할 수 없다. 로딩 화면은 다운로드 콜백의 실제 수치를 표시하고 초기화 단계에는 임의 퍼센트를 만들지 않는다.

공식 웹 조건: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
