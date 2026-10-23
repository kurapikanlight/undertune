import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../media/sleep_timer.dart';

String _countdown(Duration time) =>
    '${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';

Future<void> showSleepTimer(BuildContext context, SleepTimer timer) async {
  final duration = await showModalBottomSheet<Duration>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SleepTimerSheet(timer: timer),
  );
  if (duration != null && context.mounted) timer.start(duration);
}

class SleepTimerTile extends StatelessWidget {
  const SleepTimerTile({super.key, required this.timer, required this.onTap});
  final SleepTimer timer;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: timer,
    builder: (context, _) => ListTile(
      key: const ValueKey('sleep-timer-control'),
      title: const Text('Sleep timer'),
      subtitle: timer.error != null
          ? Text(timer.error!)
          : timer.active
          ? Text('${_countdown(timer.remaining!)} remaining')
          : null,
      leading: Icon(
        timer.error != null
            ? Icons.error_outline
            : timer.active
            ? Icons.bedtime_rounded
            : Icons.bedtime_outlined,
        color: timer.active ? Theme.of(context).colorScheme.primary : null,
      ),
      onTap: onTap,
    ),
  );
}

class _SleepTimerSheet extends StatefulWidget {
  const _SleepTimerSheet({required this.timer});
  final SleepTimer timer;
  @override
  State<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<_SleepTimerSheet> {
  final _minutes = TextEditingController();
  String? _error;
  void _custom() {
    final minutes = int.tryParse(_minutes.text.trim());
    if (minutes == null || minutes < 1 || minutes > 1440) {
      setState(() => _error = 'Enter 1–1440 minutes.');
      return;
    }
    Navigator.pop(context, Duration(minutes: minutes));
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListenableBuilder(
        listenable: widget.timer,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep timer', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              widget.timer.active
                  ? '${_countdown(widget.timer.remaining!)} remaining'
                  : 'Pause music or video after your chosen time.',
            ),
            if (widget.timer.active)
              TextButton.icon(
                onPressed: () {
                  widget.timer.cancel();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.timer_off_outlined),
                label: const Text('Cancel timer'),
              ),
            if (widget.timer.error != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.timer.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in [5, 10, 15, 30, 45, 60])
                  ActionChip(
                    label: Text('$minutes min'),
                    onPressed: () =>
                        Navigator.pop(context, Duration(minutes: minutes)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'Custom minutes',
                hintText: '1–1440',
                errorText: _error,
                counterText: '',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _custom(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _custom,
                child: const Text('Start'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
