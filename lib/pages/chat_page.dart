import 'dart:typed_data';
import '../components/chat_export.dart'; // Import the export function
import 'package:bubble/bubble.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../components/message_panel.dart';
import '../classes/msg.dart';
import '../classes/global.dart';
import 'dart:convert';
import 'package:pointycastle/asymmetric/api.dart';
import '../components/view_file.dart';
import '../encyption/rsa.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key, required this.converser}) : super(key: key);

  final String converser;

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  List<Msg> messageList = [];
  TextEditingController myController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  bool _isPlaying = false;
  final ScrollController _scrollController = ScrollController();
  bool _isFirstBuild = true; // Add this flag
  final FocusNode _focusNode = FocusNode();
  int _previousMessageCount = 0;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void initState() {
    super.initState();

    // Audio player setup
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _currentlyPlayingId = null;
          _isPlaying = false;
        });
      }
    });

    // Focus node listener for keyboard
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _scrollToBottom();
      }
    });

    // Initial scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Optional: Listen to keyboard changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioPlayer.dispose();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    if (Provider.of<Global>(context).conversations[widget.converser] != null) {
      messageList = [];
      Provider.of<Global>(context)
          .conversations[widget.converser]!
          .forEach((key, value) {
        messageList.add(value);
      });
      if (_isFirstBuild) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
          _isFirstBuild = false;
        });
      }
      // Check if new messages are added and scroll to bottom
      if (messageList.length > _previousMessageCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
        _previousMessageCount = messageList.length;
      }
    }

    Map<String, List<Msg>> groupedMessages = {};
    for (var msg in messageList) {
      String date =
          DateFormat('dd/MM/yyyy').format(DateTime.parse(msg.timestamp));
      if (groupedMessages[date] == null) {
        groupedMessages[date] = [];
      }
      groupedMessages[date]!.add(msg);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.converser),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              try {
                final file = await generatePdf(converser: widget.converser);
                if (mounted) {
                  _showExportOptions(context, file.path);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to export chat. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messageList.isEmpty
                  ? const Center(child: Text('No messages yet'))
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      itemCount: groupedMessages.keys.length,
                      itemBuilder: (BuildContext context, int index) {
                        String date = groupedMessages.keys.elementAt(index);
                        return Column(
                          children: [
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  date,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            ...groupedMessages[date]!.map(
                              (msg) {
                                String displayMessage = msg.message;
                                if (Global.myPrivateKey != null) {
                                  RSAPrivateKey privateKey =
                                      Global.myPrivateKey!;
                                  dynamic data = jsonDecode(msg.message);
                                  if (data['type'] == 'text') {
                                    Uint8List encryptedBytes =
                                        base64Decode(data['data']);
                                    Uint8List decryptedBytes =
                                        rsaDecrypt(privateKey, encryptedBytes);
                                    displayMessage =
                                        utf8.decode(decryptedBytes);
                                  }
                                }
                                return Align(
                                  alignment: msg.msgtype == 'sent'
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Bubble(
                                    style: BubbleStyle(
                                      nip: BubbleNip.no,
                                      radius: const Radius.circular(18),
                                      color: msg.msgtype == 'sent'
                                          ? const Color(0xffd1c4e9)
                                          : const Color(0xff80DEEA),
                                      elevation: 2,
                                      shadowColor:
                                          Colors.black.withOpacity(0.1),
                                      padding: const BubbleEdges.all(12),
                                      margin: BubbleEdges.only(
                                        top: 10,
                                        left: msg.msgtype == 'sent' ? 40.0 : 10,
                                        right: msg.msgtype == 'received'
                                            ? 40.0
                                            : 10,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Flexible(
                                          child: msg.message.contains('file')
                                              ? _buildFileBubble(msg)
                                              : Text(
                                                  displayMessage,
                                                  style: const TextStyle(
                                                      color: Colors.black87),
                                                ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          dateFormatter(
                                              timeStamp: msg.timestamp),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                  top: 10.0), // Add padding above MessagePanel
              child: AnimatedContainer(
                duration: Duration.zero,
                child: MessagePanel(
                  converser: widget.converser,
                  focusNode: _focusNode,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceMessageBubble(Msg msg) {
    final data = jsonDecode(msg.message);
    final bool isCurrentlyPlaying = _currentlyPlayingId == msg.id;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause Button
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: msg.msgtype == 'sent'
                  ? Colors.deepPurple.withOpacity(0.2)
                  : Colors.cyan.withOpacity(0.2),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                isCurrentlyPlaying && _isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: msg.msgtype == 'sent'
                    ? Colors.deepPurple
                    : Colors.cyan[700],
                size: 24,
              ),
              onPressed: () => _handleVoicePlayback(msg),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform/Progress Bar
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: StreamBuilder<Duration>(
                      stream: _audioPlayer.onPositionChanged,
                      builder: (context, snapshot) {
                        return FutureBuilder<Duration?>(
                          future: _audioPlayer.getDuration(),
                          builder: (context, durationSnapshot) {
                            final totalDuration =
                                durationSnapshot.data?.inMilliseconds ?? 1;
                            return LinearProgressIndicator(
                              value: isCurrentlyPlaying && snapshot.hasData
                                  ? snapshot.data!.inMilliseconds /
                                      totalDuration
                                  : 0,
                              backgroundColor: msg.msgtype != 'sent'
                                  ? Colors.cyan.withOpacity(0.1)
                                  : Colors.deepPurple.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                msg.msgtype == 'sent'
                                    ? Colors.deepPurple
                                    : Colors.cyan[700]!,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Duration Text
                StreamBuilder<Duration>(
                  stream: _audioPlayer.onPositionChanged,
                  builder: (context, snapshot) {
                    return FutureBuilder<Duration?>(
                      future: _audioPlayer.getDuration(),
                      builder: (context, durationSnapshot) {
                        String duration = '0:00';
                        if (isCurrentlyPlaying && snapshot.hasData) {
                          duration = _formatDuration(snapshot.data!);
                        } else if (durationSnapshot.hasData) {
                          duration = _formatDuration(durationSnapshot.data!);
                        }
                        return Text(
                          duration,
                          style: TextStyle(
                            fontSize: 12,
                            color: msg.msgtype == 'sent'
                                ? Colors.deepPurple[700]
                                : Colors.cyan[900],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVoicePlayback(Msg msg) async {
    try {
      final data = jsonDecode(msg.message);
      final String filePath = data['filePath'];

      if (_currentlyPlayingId == msg.id && _isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        if (_currentlyPlayingId != msg.id) {
          await _audioPlayer.stop();
          await _audioPlayer.setSource(DeviceFileSource(filePath));
          await _audioPlayer.resume();
        } else {
          await _audioPlayer.resume();
        }
        setState(() {
          _currentlyPlayingId = msg.id;
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error playing voice message')),
      );
    }
  }

  Widget _buildFileBubble(Msg msg) {
    dynamic data = jsonDecode(msg.message);
    if (data['type'] == 'voice') {
      return _buildVoiceMessageBubble(msg);
    }
    String fileName = data['fileName'];
    String filePath = data['filePath'];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            fileName,
            style: const TextStyle(color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.file_open, size: 18, color: Colors.black87),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => FilePreview.openFile(filePath),
        ),
      ],
    );
  }

  String dateFormatter({required String timeStamp}) {
    DateTime dateTime = DateTime.parse(timeStamp).toLocal();
    return DateFormat.jm().format(dateTime);
  }
}

void _showExportOptions(BuildContext context, String filePath) {
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Export Chat",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text("Open PDF"),
              onTap: () {
                OpenFilex.open(filePath);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text("Share PDF"),
              onTap: () {
                Share.shareXFiles([XFile(filePath)], text: "Chat History");
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    },
  );
}
