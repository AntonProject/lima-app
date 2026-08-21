import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/client_contract.dart';
import 'package:lima/core/models/order_term_option.dart';

void main() {
  test('parses direct and wrapped Markups/short responses', () {
    const row = {
      'id': 42,
      'prepayment_percent': '50',
      'retail': 'true',
      'wholesaler': false,
    };

    final direct = OrderTermOption.fromResponse([row]);
    final wrapped = OrderTermOption.fromResponse({'result': [row]});

    expect(direct.single.marginId, 42);
    expect(wrapped.single.prepaymentPercent, 50);
    expect(wrapped.single.supportsBuyer(false), isTrue);
    expect(wrapped.single.supportsBuyer(true), isFalse);
  });

  test('does not invent an approximate markup for an unsupported combination', () {
    const options = [
      OrderTermOption(
        marginId: 1,
        prepaymentPercent: 100,
        wholesaler: false,
        retail: true,
      ),
    ];

    expect(
      options.where(
        (option) =>
            option.prepaymentPercent == 0 && option.supportsBuyer(false),
      ),
      isEmpty,
    );
  });

  test('parses direct, wrapped and empty client contract responses', () {
    const row = {'id': '7', 'contract_number': 'A-7'};
    expect(ClientContract.fromResponse([row]).single.id, 7);
    expect(
      ClientContract.fromResponse({'data': [row]}).single.name,
      'A-7',
    );
    expect(ClientContract.fromResponse(const []), isEmpty);
  });
}
