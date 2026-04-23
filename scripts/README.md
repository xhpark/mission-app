# Automation Scripts

개발문서 `06_Automation_Script_Spec_v3.docx` 기준의 스크립트 엔트리입니다.

- `validate_sheet_data.py`: 업로드 번들 필수 컬럼/타입 검증
- `generate_content_draft.py`: 시트 데이터를 앱 콘텐츠 초안 JSON으로 변환
- `build_content_bundle.py`: 배포용 번들 생성
- `build_audio_manifest.py`: 앱 콘텐츠 기준 오디오 생성 대상(manifest) 생성
- `generate_tts_audio.py`: manifest 기준 TTS 음성 파일 생성(dry-run/실행 지원)
- `upload_content_bundle.py`: 콘텐츠 번들 업로드(연결 포인트)
- `upload_audio_bundle.py`: manifest 기준 오디오 번들 Firebase Storage 업로드(dry-run/실행 지원)
- `run_smoke_test.py`: 최소 스모크 체크
- `export_admin_report.py`: 관리자 리포트 내보내기(연결 포인트)

예시:

- `python scripts/build_audio_manifest.py`
- `python scripts/generate_tts_audio.py` (dry-run)
- `python scripts/generate_tts_audio.py --execute` (실제 생성)
- `python scripts/upload_audio_bundle.py` (dry-run)
- `python scripts/upload_audio_bundle.py --execute` (실제 업로드)
