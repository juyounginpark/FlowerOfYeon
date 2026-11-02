# GA4 설정과 지표 해석

현재 운영 설정: 측정 ID가 있으면 첫 접속부터 자동 수집한다. 첫 방문 동의창은 표시하지 않는다. 기존에 수집을 거부한 브라우저는 계속 비활성화하며, 방문 통계 · 설정에서 끄거나 다시 켤 수 있다. 자동 활성화는 명시적 동의 기록으로 저장하지 않는다. 아래 동의 기반 퍼널 설명은 이전 설정의 한계이며 현재 기본 동작은 자동 수집이다. 사전 동의가 요구되는 방문 환경에서 이 설정의 적법성을 보장하지 않는다.

## 연결

무료 Google Analytics에서 계정 → GA4 속성 → 웹 데이터 스트림을 만든다. 사이트 URL은 `https://juyounginpark.github.io/FlowerOfYeon/`이다. Analytics 360, BigQuery 유료 연동, 별도 서버, Measurement Protocol 비밀키는 필요하지 않다.

GitHub Settings → Secrets and variables → Actions → Variables → New repository variable에 `GA4_MEASUREMENT_ID`를 추가한다. 값은 실제 웹 스트림의 `G-...` 측정 ID다. 예시 ID를 사용하지 않는다. Actions를 다시 실행하면 매 빌드 자동 삽입된다. 변수가 없으면 분석 UI·Google 스크립트·전송 모두 비활성이고 게임은 그대로 실행된다. 측정 ID는 공개 식별자이며 비밀키가 아니다. 잘못된 형식은 빌드에서 거부한다.

첫 방문 시 Google 스크립트를 자동 로드한다. 저장된 거부 설정이 있으면 로드하지 않는다. 수집을 꺼도 게임은 실행된다. 화면의 분석 설정에서 언제든 거부/철회할 수 있다. 브라우저 로컬 저장소에는 동의 여부만 저장하며 임의 사용자 ID를 만들지 않는다. 광고 목적의 consent는 항상 denied이고 Google signals는 꺼져 있다.

GA 관리에서 데이터 보관 기간·접근권한·Google signals·광고 연동을 확인하고, 향상된 측정의 폼 상호작용/사이트 검색/URL 기반 개인 정보 수집을 꺼 둔다. 코드에서는 page_location의 query/hash와 referrer의 경로를 제거한다. 이메일·이름·비밀번호·채팅·민감정보를 보내지 않으며 이벤트 파라미터는 고정 허용 목록만 통과한다. Google 태그 자체가 동의 후 쿠키, 기기/브라우저·대략적 지역·기본 참여 정보를 처리할 수 있다는 안내가 필요하다. 관할별 법적 적합성 검토를 대신하지 않는다.

## 이벤트와 연결 지점

| 이벤트 | 실제 관측 지점 / 파라미터 |
| --- | --- |
| page_view | 동의 후 gtag config의 자동 페이지 조회 |
| game_load_start | HTML의 engine.startGame 직전 |
| game_files_loaded | Godot 다운로드 콜백에서 유효한 current == total 관측 시 1회 |
| game_engine_started | startGame Promise 성공 시 1회 |
| game_load_complete | Analytics Autoload ready: 엔진의 노드 초기화 / load_seconds |
| game_start | 첫 월드가 실제로 조작 가능한 상태 / game_mode=story |
| level_start | 새 스테이지·재시도에서 실제 조작 가능할 때 1회 / level_number |
| level_complete | world.complete_stage 중복 방지 분기 후 / level_number, duration_seconds |
| level_fail | 기존 낙사 복귀 및 명시적 재시작 / failure_type, level_number, duration_seconds |
| playtime_checkpoint | 실제 누적 플레이 매 60초 / play_seconds, play_delta_seconds, level_number |
| game_end | 맵 선택/타이틀 복귀, 월드 제거, 엔딩, 페이지 종료 / play_seconds, play_delta_seconds, level_number |
| game_load_error | HTML의 엔진 시작 실패 또는 필수 기능 부재 / error_type(enum) |

level_number는 게임 내부 번호다. 1~3은 연습맵, 4~12는 본편 1~9장이다. 낙사는 컷 상태를 초기화하는 게임 재시작이 아니라 분석상 새 시도만 시작한다. 스토리가 복귀를 미룰 때 반복되는 낙사 신호는 회복 경계에 도달할 때까지 한 번만 집계한다. 선택/재시작으로 바뀐 기존 게임 상태만 관찰하며 게임 규칙을 추가하지 않는다. 실패 원문이나 stack trace를 GA로 보내지 않는다.

`game_load_complete`(Autoload ready)와 `game_engine_started`(브라우저 Promise 완료)는 서로 다른 관측점이므로 엄격한 시간 순서를 가정하지 않는다. 다운로드 진행률은 알려진 total에만 표시하고 그 외 단계는 초기화 안내만 표시한다. 네트워크 장애와 탭 종료의 모든 실패를 관측할 수는 없다.

## 실제 플레이시간

GDScript의 단조 시계 `Time.get_ticks_msec()`를 사용한다. 월드가 처리 가능하며 일시정지·completed·ending·player.paused·input_locked·전환·포커스 이탈 상태가 아닐 때만 누적한다. 대화가 기존 공통 일시정지/입력 잠금을 적용하면 함께 제외된다. 초과 브라우저 정지 구간을 과다 산입하지 않기 위해 한 샘플은 최대 1초로 제한한다(긴 활성 프레임에서도 보수적으로 과소 계산할 수 있음).

60초 체크포인트와 종료 이벤트에 **직전 전송 이후 증가분** `play_delta_seconds`를 전송한다. 누적값 `play_seconds`를 이벤트마다 합하면 중복되므로 합산하면 안 된다. 페이지 종료에 대비한 마지막 스냅샷은 매 1초 갱신하며 강제 종료·네트워크 장애에서는 마지막 구간이 유실될 수 있다. 자동 생성한 세션 ID는 없다. bfcache 진입을 종료로 처리하지 않는다. 일반 종료 이벤트는 페이지 측에서 중복을 방지한다.

이름이 game_end라도 브라우저 이벤트 전송은 최선 노력이다. 사용자가 동의하기 전 플레이한 시간이 동의 후 체크포인트에 포함될 수 있지만, 과거 이벤트를 재전송하지는 않는다. 따라서 분석 자료는 동의한 관측 표본이며 전체 사용자의 완전한 기록이 아니다.

## GA4 확인과 보고서

실제 측정 ID를 등록하고 재배포한 다음, 동의한 브라우저에서 관리 → DebugView(태그 디버깅을 별도 활성화) 또는 보고서 → 실시간에서 이벤트를 확인한다. Network의 Google `/g/collect` 요청도 확인한다. 현재 실제 ID가 없어서 Google 수신·실시간 통계는 검증하지 않았다. 광고 차단과 네트워크 오류로 전송이 차단되어도 게임은 영향을 받지 않는다.

표준 보고서의 사용자 획득/트래픽 획득, 인구통계 상세, 기술 상세, 참여에서 총/활성 사용자, 신규/재방문, 조회수, 국가/지역, 기기, 브라우저, 소스/매체, 참여 세션과 평균 참여시간을 본다. 탐색의 날짜·주·월 차원으로 추이를 구성한다. GA4 평균 참여시간은 페이지가 포커스된 참여시간이고 **게임의 실제 플레이시간과 다르다**. 동의 전·차단·지연 방문은 빠지며 referrer 최소화로 상세 유입 경로가 줄 수 있다.

관리 → 데이터 표시 → 맞춤 정의에서 다음을 **이벤트 범위**로 등록한다.

| 종류 | 파라미터 | 단위 |
| --- | --- | --- |
| 맞춤 측정기준 | level_number, game_mode, failure_type, error_type | 텍스트/범주 |
| 맞춤 측정항목 | play_delta_seconds | 초 |
| 맞춤 측정항목 | play_seconds | 초(누적 스냅샷, 합계 사용 금지) |
| 맞춤 측정항목 | duration_seconds | 초 |
| 맞춤 측정항목 | load_seconds | 초 |

평균 실제 플레이시간은 탐색에서 `(playtime_checkpoint와 game_end의 play_delta_seconds 합계) / game_start 이벤트 수`로 계산한다. GA UI의 계산 측정항목 제공 여부에 따라 같은 표를 CSV로 내려 무료 스프레드시트에서 계산할 수 있다. 종료 이벤트 유실·동의 시점 차이 때문에 근사치다. 신규 맞춤 정의는 반영까지 시간이 걸리고 과거 데이터에 소급 적용되지 않을 수 있다.

순서 퍼널: page_view → game_load_start → game_files_loaded → game_load_complete → game_start. 엔진 시작 관측은 별도 game_engine_started로 비교한다. 동일한 관측 범위/세션 기준으로 로딩 완료율=완료/시작, 시작률=game_start/완료, 실패율=game_load_error/시작을 계산한다. 분모가 0이면 값을 만들지 않는다. 동의를 로딩 도중 한 사용자의 누락된 앞 단계는 성공으로 간주하지 않는다. 이탈률은 1-전환율이라는 관측 근사치이며 미수집 실패를 확정 이탈로 단정하지 않는다.

스테이지별 level_start → level_complete 퍼널에 level_number를 적용해 완료/이탈을 비교한다. 재시도가 있으므로 단순 이벤트 수 비율은 사용자 완료율과 다르다. 세션·사용자 단위 퍼널로 확인한다. 평균 초기화 시간은 game_load_complete의 load_seconds 평균(페이지 스크립트 초기화~Autoload ready)이며 순수 WASM 컴파일 시간은 아니다.

참고: https://developers.google.com/analytics/devguides/collection/ga4/events

참고: https://developers.google.com/analytics/devguides/collection/ga4/event-parameters

참고: https://developers.google.com/tag-platform/security/concepts/consent-mode
