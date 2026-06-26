/// 학습 카드의 정적 텍스트 총 길이로 "읽는 데 걸리는 시간"을 추정해 자동 스크롤 지연을 계산한다.
///
/// 하단의 다음 버튼이 가변 길이 내용 아래에 있어, 사용자가 위쪽 핵심 내용을 숙지할 만한
/// 시점에 자동으로 살짝 스크롤해 버튼을 노출시키기 위한 지연을 산출한다. 너무 이르면 내용
/// 숙지 전에 스크롤되고, 너무 늦으면 사용자가 직접 스크롤하므로 내용 길이에 비례시킨다.
library;

const int _autoScrollBaseMs = 2000; // 화면 오리엔테이션 + 음성 자동재생 시작 여유
const int _autoScrollPerCharMs = 60; // 초보자가 한/태/발음 혼합 텍스트를 읽는 보수적 추정
const int _autoScrollMinMs = 3000;
const int _autoScrollMaxMs = 12000;

/// 사용자가 다음 버튼 전에 읽는 정적 텍스트 길이([contentCharCount])로 자동 스크롤 지연을 계산.
///
/// 결과는 [_autoScrollMinMs] ~ [_autoScrollMaxMs] 범위로 클램프된다.
Duration computeAutoScrollDelay({required int contentCharCount}) {
  final safeCount = contentCharCount < 0 ? 0 : contentCharCount;
  final raw = _autoScrollBaseMs + _autoScrollPerCharMs * safeCount;
  final clamped = raw.clamp(_autoScrollMinMs, _autoScrollMaxMs);
  return Duration(milliseconds: clamped);
}
