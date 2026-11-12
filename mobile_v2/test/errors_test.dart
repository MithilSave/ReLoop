import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors.dart';

// Same cases as the web app's api/errors.test.ts.
void main() {
  group('apiErrorFromBody', () {
    test('reads the backend error envelope including details', () {
      final e = apiErrorFromBody(409, {
        'error': {'code': 'ALLOCATION_EXCEEDS_AVAILABLE', 'message': 'Requested 200 kg exceeds available 130 kg', 'details': {'available_kg': '130.000'}},
      });
      expect(e.status, 409);
      expect(e.code, 'ALLOCATION_EXCEEDS_AVAILABLE');
      expect((e.details as Map)['available_kg'], '130.000');
    });

    test('maps pydantic 422 details to field errors', () {
      final e = apiErrorFromBody(422, {
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Request validation failed',
          'details': [
            {'loc': ['body', 'estimated_kg'], 'msg': 'Field required'},
          ],
        },
      });
      expect(e.fieldErrors(), {'estimated_kg': 'Field required'});
    });

    test('reads FastAPI default detail and unknown bodies', () {
      expect(apiErrorFromBody(404, {'detail': 'Not Found'}).message, 'Not Found');
      expect(apiErrorFromBody(502, null).code, 'HTTP_502');
    });

    test('reports network failures as status 0', () {
      expect(toApiError(Exception('socket')).status, 0);
      expect(describeError(toApiError(Exception('socket'))).title, 'Backend unavailable');
    });

    test('AI model not connected is a 503 with its own code', () {
      final e = apiErrorFromBody(503, {
        'error': {'code': 'AI_MODEL_NOT_CONFIGURED', 'message': 'AI polymer detection is not connected.'},
      });
      expect(e.code, 'AI_MODEL_NOT_CONFIGURED');
    });
  });
}
