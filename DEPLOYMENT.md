# GitHub Pages 배포

저장소: https://github.com/juyounginpark/FlowerOfYeon

사이트: https://juyounginpark.github.io/FlowerOfYeon/

## 자동 빌드

`.github/workflows/deploy.yml`은 main push 또는 Run workflow로 실행한다. 공식 Godot 4.7.2 엔진과 export_templates.tpz를 다운로드하고 공식 SHA-512 목록으로 확인한다. Web 단일 스레드 템플릿만 설치한다. Godot 에디터를 dummy 렌더러·오디오로 열어 임포트한 후 종료하며 게임 씬을 실행하지 않는다. 새 체크아웃의 폰트 캐시를 부트스트랩하고 설정을 복원한 뒤 다시 임포트한다.

리소스 조사 → 임포트 → Web release export → GA4 선택 설정 → 정적 테스트 → HTTP HEAD 검사 → Pages 아티팩트 순서다. main에는 빌드 파일을 커밋하지 않는다. `build/web`만 게시하며 소스·문서·테스트·로그는 사이트에 올리지 않는다. 실패 로그와 용량 보고서는 별도 evidence 아티팩트에서 하루 동안 확인할 수 있다.

build는 contents:read만, deploy는 contents:read/pages:write/id-token:write만 가진다. github-pages 환경을 사용하며 build가 성공해야 deploy가 실행된다. 실패한 빌드는 기존 배포를 교체하지 않는다. Actions 공식 최신 릴리스(작업 시점 확인): checkout v7, setup-python v7, upload-artifact v7, configure-pages v6, upload-pages-artifact v5, deploy-pages v5.

## Pages 설정과 배포

Settings → Pages → Source: GitHub Actions. 이 저장소는 API로 workflow 방식 Pages를 활성화했다. 환경 보호 규칙이나 조직 정책이 변경되면 관리자의 추가 조치가 필요할 수 있다.

main에 소스를 push하면 자동 빌드된다. 코드 변경 없이 다시 배포하려면 Actions → Build and deploy FlowerOfYeon → Run workflow. GA4 변수 변경만으로는 push 이벤트가 생기지 않으므로 수동 실행한다. 배포 결과는 github-pages 환경 URL에서 확인한다.

## 경로, 캐시, 서비스 워커

HTML과 엔진 설정은 상대 경로를 사용한다. 필수 바이너리·스크립트·아이콘·오디오 worklet을 `releases/<콘텐츠 해시>/` 아래에 함께 둔다. 콘텐츠가 바뀌면 URL이 바뀌므로 구버전 바이너리와 새 HTML이 섞이는 문제를 줄인다. 동일 빌드는 동일 URL을 사용해 브라우저 캐시를 재사용한다. 호스팅 정책상 HTML 캐시를 즉시 무효화할 수는 없으며, 업데이트 직후에는 강력 새로고침을 사용할 수 있다.

PWA/서비스 워커는 새로 등록하지 않는다. 현재 게임 디렉터리와 정확히 같은 scope의 구형 `index.service.worker.js` 등록만 해제한다. 다른 프로젝트의 캐시나 서비스 워커는 건드리지 않는다. 이전 워커가 이미 제어 중인 탭은 새로고침이 필요할 수 있다.

## 대용량과 0원 운영

원본 개별 파일은 100MiB 미만임을 조사했다. Git LFS·외부 CDN·유료 서비스는 사용하지 않는다. 바이너리는 Actions에서 생성한다. 원본 저장소의 이력/원격을 덮어쓰지 않고 실제 작업 트리의 소스 스냅샷으로 이 저장소의 최초 커밋을 만든다. 생성 캐시·이전 빌드·output/artifacts는 복사 대상에서 제외하며 원본 아트·음원·씬은 바이트 일치를 확인했다.

무료 공개 저장소의 표준 Ubuntu 러너를 사용한다. 더 큰 유료 러너, 과금 예산, 카드 등록은 설정하지 않는다. 공식 템플릿 다운로드는 매 실행 약 1.28GB이며 GitHub 호스팅 러너에서 수행한다. 증빙·Pages 아티팩트 보관 기간은 1일로 제한한다. 자주 실행하면 계정별 아티팩트 저장 한도에 걸릴 수 있으므로 불필요한 재빌드를 피하고 한도 도달 시 중단한다. 이 구현은 계정의 결제 설정을 변경하지 않는다.

Pages 게시 사이트 제한은 1GB, 배포 제한은 10분, 월 대역폭 소프트 제한은 100GB다. 빌드는 1,000,000,000바이트 미만인지 검사하고 초과 시 배포하지 않는다. deploy 작업에도 10분 제한이 있다. 500MB를 매번 전부 받는 경우 월 약 200회, 기존 539MB 기준 약 185회, 최적화 후 461MB 기준 약 216회면 100GB에 접근한다. 실제 압축과 캐시 적중률에 따라 달라지며 이 수치는 동시 사용자 수가 아니다. 유입 증가 시 제한/서비스 중단 위험이 있다. 자동 유료 서비스로 전환하지 않는다.

공식 근거: https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits

공식 Actions 구성: https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages
