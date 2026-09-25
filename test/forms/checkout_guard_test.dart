import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/route/presentation/states/route_state.dart';

void main() {
  group('Checkout Guard & Required Surveys Tests (§1 & §2 Spec 23/09/2026)', () {
    const requiredForm = MarketFormConfigEntity(
      configId: 101,
      formId: 1,
      code: 'survey_mandatory',
      name: 'Khảo sát bắt buộc giá bán',
      kind: 'survey',
      isRequired: true,
      sortOrder: 1,
      schema: MarketFormSchemaEntity(blocks: []),
    );

    const optionalForm = MarketFormConfigEntity(
      configId: 102,
      formId: 2,
      code: 'survey_optional',
      name: 'Khảo sát trưng bày tùy chọn',
      kind: 'survey',
      isRequired: false,
      sortOrder: 2,
      schema: MarketFormSchemaEntity(blocks: []),
    );

    test('Blocks checkout when required survey is unsubmitted', () {
      const state = CheckInState(
        surveyForms: [requiredForm, optionalForm],
        submittedSurveyConfigIds: {},
      );

      expect(state.hasUnsubmittedRequiredSurveys, isTrue);
      expect(state.unsubmittedRequiredSurveys.length, 1);
      expect(state.unsubmittedRequiredSurveys.first.configId, 101);
      expect(state.unsubmittedRequiredSurveys.first.name, 'Khảo sát bắt buộc giá bán');
    });

    test('Allows checkout when all required surveys are submitted', () {
      final state = const CheckInState(
        surveyForms: [requiredForm, optionalForm],
        submittedSurveyConfigIds: {},
      ).copyWith(
        submittedSurveyConfigIds: {101}, // Đã nộp form bắt buộc 101, form 102 tùy chọn
      );

      expect(state.hasUnsubmittedRequiredSurveys, isFalse);
      expect(state.unsubmittedRequiredSurveys, isEmpty);
    });

    test('Allows checkout when all surveys are optional', () {
      const state = CheckInState(
        surveyForms: [optionalForm],
        submittedSurveyConfigIds: {},
      );

      expect(state.hasUnsubmittedRequiredSurveys, isFalse);
      expect(state.unsubmittedRequiredSurveys, isEmpty);
    });

    test('Allows checkout when there are no surveys for the store', () {
      const state = CheckInState(
        surveyForms: [],
        submittedSurveyConfigIds: {},
      );

      expect(state.hasUnsubmittedRequiredSurveys, isFalse);
    });
  });
}
