import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/branding.dart';
import '../widgets/media_image.dart';

Future<void> showAboutUndertune(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = scheme.onSurface.withValues(alpha: .72);
    return Dialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(flex: 3, child: BrandWordmark(width: 190)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          key: const ValueKey('kafeyn-signature'),
                          width: 54,
                          height: 54,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Image.asset(
                            'assets/branding/signature.webp',
                            cacheWidth: artworkDecodeWidth(context, 42),
                            fit: BoxFit.contain,
                            semanticLabel: 'kafeyn',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Discover music and videos, collect your favorites, and listen in your own atmosphere. Powered by PipePipe’s open-source extraction library.',
                style: TextStyle(color: secondary, height: 1.5),
              ),
              const SizedBox(height: 22),
              Text('Developed by', style: TextStyle(color: secondary)),
              Text(
                'Kafeyn',
                style: feelfreeHeadingStyle.copyWith(fontSize: 46.8),
              ),
              const SizedBox(height: 14),
              _link(
                context,
                Icons.person_outline,
                'LinkedIn',
                'Anass Iguedmi — Open profile',
                'https://www.linkedin.com/in/anass-iguedmi-183022373/',
              ),
              _link(
                context,
                Icons.code,
                'GitHub',
                'kurapikanlight',
                'https://github.com/kurapikanlight',
              ),
              _link(
                context,
                Icons.favorite,
                'Support This Project',
                'Your support helps keep this project growing.',
                'https://ko-fi.com/kafeyn_',
              ),
              const Divider(height: 32),
              const Text(
                'Built on open source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'Undertune is based on PipePipe. Special thanks to InfinityLoop1308 and all PipePipe developers and contributors for their work, and to the NewPipe team and contributors for the original foundation.',
                style: TextStyle(color: secondary, height: 1.5),
              ),
              _link(
                context,
                Icons.open_in_new,
                'PipePipe',
                'Project and contributors',
                'https://github.com/InfinityLoop1308/PipePipe',
              ),
              _link(
                context,
                Icons.open_in_new,
                'NewPipe',
                'Original foundation',
                'https://github.com/TeamNewPipe/NewPipe',
              ),
              TextButton(
                onPressed: () => _showLicense(
                  context,
                  'PipePipeExtractor · GPL-3.0',
                  'assets/licenses/PipePipeExtractor.txt',
                ),
                child: const Text('PipePipeExtractor license'),
              ),
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Undertune',
                ),
                child: const Text('Package licenses'),
              ),
              const Divider(height: 32),
              const Text(
                'Font credit & license',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'Feelfree Personal Use Regular by Billy Argel. Copyright © 2022 Billy Argel. All rights reserved.',
                style: TextStyle(color: secondary, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Personal use only. Commercial licenses and complete versions are available from the designer.',
                style: TextStyle(color: secondary, height: 1.5),
              ),
              _link(
                context,
                Icons.text_fields,
                'Feelfree — Billy Argel',
                'Designer and licensing details',
                'https://billyargel.com/product/feelfree/',
              ),
              TextButton(
                onPressed: () => _showLicense(
                  context,
                  'Feelfree · Personal use only',
                  'assets/licenses/Feelfree.txt',
                ),
                child: const Text('Feelfree font license'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);

Future<void> _showLicense(
  BuildContext context,
  String title,
  String asset,
) async {
  final license = await rootBundle.loadString(asset);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: SelectableText(license)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Widget _link(
  BuildContext context,
  IconData icon,
  String title,
  String subtitle,
  String url,
) => ListTile(
  contentPadding: EdgeInsets.zero,
  leading: Icon(icon),
  title: Text(title),
  subtitle: Text(subtitle),
  trailing: const Icon(Icons.north_east, size: 16),
  onTap: () async {
    try {
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('No app available');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Could not open this link.')),
        );
      }
    }
  },
);
