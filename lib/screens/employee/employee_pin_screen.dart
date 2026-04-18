import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../services/firestore_service.dart';

class EmployeePinScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onBack;

  const EmployeePinScreen({
    super.key,
    required this.onSuccess,
    required this.onBack,
  });

  @override
  State<EmployeePinScreen> createState() => _EmployeePinScreenState();
}

class _EmployeePinScreenState extends State<EmployeePinScreen>
    with SingleTickerProviderStateMixin {
  String _entered = '';
  String? _storedPin;
  bool _loading = true;
  bool _error = false;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));
    _loadPin();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPin() async {
    final pin = await FirestoreService.getEmployeePin();
    if (mounted) setState(() { _storedPin = pin; _loading = false; });
  }

  void _onDigit(String digit) {
    if (_entered.length >= 4) return;
    setState(() { _entered += digit; _error = false; });
    if (_entered.length == 4) _checkPin();
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() { _entered = _entered.substring(0, _entered.length - 1); _error = false; });
  }

  Future<void> _checkPin() async {
    // Brief pause so the 4th dot renders before we transition
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    if (_entered == _storedPin) {
      widget.onSuccess();
    } else {
      _shakeCtrl.forward(from: 0);
      setState(() { _error = true; _entered = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) widget.onBack(); },
      child: Scaffold(
        backgroundColor: kBackground,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : _storedPin == null
                  ? _buildNotSetUp()
                  : _buildPinEntry(),
        ),
      ),
    );
  }

  Widget _buildNotSetUp() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Spacer(),
          Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 24),
          const Text(
            'Employee access not set up yet.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Contact the owner to set up a PIN.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          TextButton(
            onPressed: widget.onBack,
            child: const Text('Go back'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPinEntry() {
    return Column(
      children: [
        const Spacer(flex: 2),
        Icon(Icons.lock_open_outlined, size: 52, color: kPrimary),
        const SizedBox(height: 20),
        const Text('Employee Access',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Enter your PIN to continue',
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 44),

        // PIN dots
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) =>
              Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _entered.length;
              return Container(
                width: 58,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? (_error ? kRed : kPrimary)
                      : Colors.grey[200],
                  border: Border.all(
                    color: filled
                        ? (_error ? kRed : kPrimary)
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 16),
        AnimatedOpacity(
          opacity: _error ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Text('Incorrect PIN',
              style: TextStyle(color: kRed, fontWeight: FontWeight.w600, fontSize: 13)),
        ),

        const Spacer(flex: 2),
        _buildPad(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _padRow(['1', '2', '3']),
          const SizedBox(height: 14),
          _padRow(['4', '5', '6']),
          const SizedBox(height: 14),
          _padRow(['7', '8', '9']),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72),
              _padKey('0'),
              _backKey(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _padRow(List<String> digits) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: digits.map(_padKey).toList(),
      );

  Widget _padKey(String digit) {
    return GestureDetector(
      onTap: () => _onDigit(digit),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[100],
        ),
        alignment: Alignment.center,
        child: Text(digit,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _backKey() {
    return GestureDetector(
      onTap: _onBackspace,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[100]),
        alignment: Alignment.center,
        child: const Icon(Icons.backspace_outlined, size: 26, color: Colors.black54),
      ),
    );
  }
}
