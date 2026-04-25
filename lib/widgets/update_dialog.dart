import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

class UpdateDialog extends StatefulWidget {
  final String version;
  final String releaseNotes;
  final String downloadUrl;

  const UpdateDialog({
    super.key,
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  OtaEvent? _currentEvent;
  bool _isDownloading = false;

  void _startUpdate() {
    setState(() {
      _isDownloading = true;
    });

    try {
      OtaUpdate()
          .execute(widget.downloadUrl)
          .listen(
        (OtaEvent event) {
          debugPrint('OTA Status: ${event.status}, Value: ${event.value}');
          setState(() {
            _currentEvent = event;
          });
          
          if (event.status == OtaStatus.INSTALLING) {
            // Keep the dialog for a second before closing to ensure the intent is fully handled
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) Navigator.of(context).pop();
            });
          }
        },
        onError: (e) {
          debugPrint('OTA Update Error: $e');
          setState(() {
            _isDownloading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Update failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('Failed to execute update: $e');
      setState(() {
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.white.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.system_update, color: Colors.blueAccent),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'New Update Available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Version ${widget.version}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.releaseNotes.isNotEmpty) ...[
                const Text(
                  'What\'s New:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.releaseNotes,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (_isDownloading) ...[
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _currentEvent?.value != null 
                          ? double.tryParse(_currentEvent!.value!)! / 100 
                          : 0,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getStatusMessage(),
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                )
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Later', style: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _startUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Update Now'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusMessage() {
    if (_currentEvent == null) return 'Starting download...';
    switch (_currentEvent!.status) {
      case OtaStatus.DOWNLOADING:
        return 'Downloading... ${_currentEvent!.value}%';
      case OtaStatus.INSTALLING:
        return 'Installing update...';
      case OtaStatus.ALREADY_RUNNING_ERROR:
        return 'Update already in progress';
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        return 'Permission denied';
      case OtaStatus.INTERNAL_ERROR:
        return 'Internal error occurred';
      default:
        return 'Processing update...';
    }
  }
}
