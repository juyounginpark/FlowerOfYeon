# FlowerOfYeon

민화와 한지 표현을 사용하는 Godot 4 퍼즐 게임입니다. 연습맵 3개와 본편 9개 스테이지, 종이 절단·물리 퍼즐 및 엔딩을 포함합니다. 실제 로컬 게임 소스와 원본 리소스로 구성되어 있습니다.

플레이 주소: https://juyounginpark.github.io/FlowerOfYeon/

저장소: https://github.com/juyounginpark/FlowerOfYeon

## 개발과 실행

Godot **4.7.2 stable 공식 GDScript 에디터**로 루트 `project.godot`을 여세요. 시작 씬은 `scenes/gametitle/GameTitleAnimated.tscn`입니다. 데스크톱 기본 렌더러는 Forward+, 웹은 Compatibility(WebGL 2.0)입니다. C#/GDExtension 의존성은 없습니다.

오디오·이미지는 프로젝트에 포함되어 있습니다. 에디터가 리소스를 임포트한 뒤 프로젝트 실행 기능을 사용합니다. 이 작업에서는 저장소 규칙에 따라 게임·GPU·브라우저 플레이는 실행하지 않았습니다. 기존 기능 설명은 [원본 문서](docs/ORIGINAL_PROJECT_README.md)에 보존했습니다.

## 웹 빌드

공식 Godot 4.7.2와 같은 버전의 export templates, Python 3.13을 설치한 뒤:

```powershell
./tools/export_web.ps1 -Godot 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
```

또는 플랫폼에 맞는 Godot 실행 파일로 다음을 수행합니다.

```text
python tools/web_pipeline.py prepare
python tools/import_project.py /path/to/godot
/path/to/godot --headless --rendering-driver dummy --audio-driver Dummy --export-release Web build/web/index.html
python tools/web_pipeline.py finish
python tools/verify_web.py
```

결과는 `build/web/`에 생성됩니다. HTTP 서버에서 해당 디렉터리를 제공하세요. index.html 더블클릭(file://)은 지원하지 않습니다. 상대 경로를 사용하므로 `/FlowerOfYeon/` 아래에서 제공합니다. 최초 다운로드가 크므로 느린 연결에서는 시간이 걸립니다. 모바일 지원과 그래픽 동일성은 실기 검증 전까지 보장하지 않습니다.

main push 및 Actions의 수동 실행으로 자동 빌드·배포됩니다. 빌드 산출물은 main에 커밋하지 않습니다. 측정 ID가 없으면 분석은 꺼집니다. 분석 동의 없이도 게임을 이용할 수 있습니다.

- [배포·무료 한도](DEPLOYMENT.md)
- [GA4 설정·실제 플레이시간](ANALYTICS_SETUP.md)
- [용량 측정·최적화와 한계](WEB_OPTIMIZATION.md)
