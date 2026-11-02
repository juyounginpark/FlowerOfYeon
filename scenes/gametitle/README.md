# 연의 꽃 — 독립 타이틀 애니메이션

프로젝트 시작 씬은 `GameTitleAnimated.tscn`입니다. 타이틀에서 `게임 시작`을 누르면 시작 컷씬(`opening.tscn`)으로 이동하고, 컷씬의 네 장면이 모두 펼쳐진 뒤 E를 누르면 로비/맵 선택(`menu.tscn`)으로 이동합니다.

## 에디터에서 조절하기

| 노드 | Inspector / AnimationPlayer 항목 |
| --- | --- |
| GameTitleAnimated | `Lotus Lift Px` (4), `Reflection Follow Ratio` (0.3), `Reflection Response Seconds` (0.16), `Reflection Opacity` (0.25) |
| Composition/Ripple1~3 | `Start Width` (120), `End Width` (1400), `Peak Opacity` (0.22) |
| Composition/CloudLeft~Small | `Base Position`, `Amplitude Px`, `Period Seconds`, `Initial Phase` |
| Composition/LotusMotion/Lotus | `Outline Width Px` (3), `Fade Seconds` (0.08): 실제 연꽃 위에 마우스를 올릴 때 흰색 테두리 표시 |
| Composition/LotusMotion/StartPrompt | `Paint Seconds` (0.85): 붓칠 시간, `Text Offset Y` (8): 게임 시작 글자의 세로 보정 |
| Credits | `Credits Text`: 게임잼·개발 기간·팀 단오 제작진 및 음원 6곡의 출처·CC BY 라이선스 안내 (스크롤 지원) |
| 각 Artwork / Lotus / Reflection / Title Sprite2D | `Position`, 균일한 `Scale`로 정적 배치 조절 |
| AnimationPlayer → LotusBreath | 8초 반복. `lift_phase`, 각 물결의 `expansion`과 `visibility_weight` 키프레임 |

`lift_phase`는 0~1의 정규화된 움직임입니다. 반사는 연꽃 이동량의 30%만 부드럽게 따라오며, 응답 시간 0.16초의 감쇠를 적용합니다. 고정 지연 후 출발하는 방식이 아니라 천천히 반응하는 방식입니다. 기본 설정에서 반사 이동량은 최대 1.2px이며, 기존 위치와 이미지 비율은 유지됩니다. 에디터 탐색에서는 해당 시점의 축소된 이동량을 바로 표시하고 실행 중에 감쇠를 적용합니다. 물결 `expansion`도 시작 너비~끝 너비 사이의 0~1입니다. `visibility_weight`는 최대 불투명도에 곱하는 0~1입니다. 애니메이션은 이 세 값만 기록하며, 스크립트가 최종 Sprite 속성을 계산합니다. 계산되는 Sprite의 위치/투명도에 별도의 애니메이션 트랙을 추가하면 충돌할 수 있습니다.

연꽃은 0.8~1.6초 사이에 살짝 올라왔다 내려오며 물결은 1.6/2.0/2.4초부터 각각 4초간 진행합니다. 6.4~8초는 완전한 정지 구간입니다. RESET과 저장된 기본 상태 모두 물결 투명도 0입니다. 구름의 시간은 AnimationPlayer와 별개이며 루프 경계에서 초기화되지 않습니다.

연꽃에 마우스를 올리면 기존 `stage_intro.gd`의 붓칠 이미지·영역 추출 방식·붓끝 기준점·sweep 셰이더를 재사용해 가운데를 칠합니다. 그 위에 기존 HS-Winter-Snowflake 글꼴로 `게임 시작` 버튼을 표시합니다. 버튼을 클릭하면 시작 컷씬으로 이동합니다. 포인터를 치우면 사라지고, 완전히 사라진 뒤 다시 올리면 재생됩니다. 기존 스테이지 제목 스크립트와 공용 리소스는 수정하지 않습니다.

## 투명 여백과 표시 기준

알파가 0보다 큰 모든 픽셀을 포함한 경계입니다. 원본 텍스처는 자르거나 반전하지 않았고, Sprite2D `offset`만 사용해 기준점을 맞췄습니다. 프레임 전체가 유지되므로 가장자리 반투명 픽셀이 잘리지 않습니다.

| 원본 | 알파 영역 x, y, 너비, 높이 | 표시 기준 |
| --- | --- | --- |
| title_logo.png | 0, 19, 1068, 1429 | 중심 793,282 / 높이 470 |
| lotus-2.png | 25, 20, 1729, 848 | 하단 중앙 793,869 / 너비 594 |
| 단순화된 수련 반사 스프라이트.png | 61, 0, 2075, 724 | 상단 중앙 793,805 / 너비 610 |
| ripple_ring.png | 51, 28, 2115, 658 | 중심 793,852 / 너비 120~1400 |
| cloud_left.png | 0, 23, 2151, 686 | 기준 중심 250,455 / 너비 460 |
| cloud_right.png | 50, 11, 2106, 687 | 기준 중심 1310,470 / 너비 450 |
| cloud_small.png | 57, 13, 2097, 711 | 기준 중심 390,300 / 너비 280 |

배경 `Background`는 원본 비율을 유지하면서 화면 전체를 채웁니다(Keep Aspect Covered). 창 비율에 따라 배경 가장자리 일부만 잘리며 별도 여백은 없습니다. 연꽃·제목은 `Composition` 부모에서 1586×992 기준으로 비율을 유지해 중앙 정렬합니다. 크레딧은 화면을 채운 배경의 오른쪽 아래에서 24px 안쪽에 배치됩니다. 반사 원본을 상하 반전하지 않습니다.

검증은 프로젝트 작업 규칙에 따라 정적 검토 및 `--headless --rendering-driver dummy --audio-driver Dummy --check-only --script <스크립트>` 문법 검사로 한정합니다. 게임이나 런타임 검증 스크립트는 실행하지 않습니다.

물결과 연꽃의 정규화 키는 정수가 아닌 실수(0.0~1.0)로 저장합니다. 정수 보간으로 크기·투명도가 계단식으로 바뀌는 것을 방지합니다. 물결은 완만하게 감속하고 투명도에는 smoothstep을 적용합니다. 반사는 눈에 띄는 그림 영역이 꽃 밑에 밀착되도록 위쪽 기준점을 805로 보정했습니다.
