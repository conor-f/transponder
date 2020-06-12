import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'package:traindown/traindown.dart';

enum SessionMenuOption { delete, email }

class Session {
  File file;

  Session(this.file);

  String get name => file.path.split('/').last ?? 'Traindown Session';
}

void main() => runApp(MaterialApp(home: Scaffold(body: Transponder())));

class _Transponder extends State<Transponder> {
  Session _activeSession;
  Directory _appData;
  final List<Session> _sessions = [];

  Future<void> _initAppData() async {
    Directory directory = await getApplicationDocumentsDirectory();
    setState(() => _appData = directory);
    List<FileSystemEntity> files = directory.listSync();
    if (files.isNotEmpty) {
      files.forEach((file) => _sessions.add(Session(file)));
    }
  }

  String fullFilePath(String filename) =>
      '${_appData.path}/$filename.traindown';

  Future<void> _createSession() async {
    Session session = Session(File(fullFilePath('untitled')));
    setState(() {
      _sessions.add(session);
      _activeSession = session;
      _sessionEditor();
    });
  }

  Widget _createSessionButton() {
    return FlatButton(
        textColor: Colors.blue,
        child: Text('Add new session'),
        onPressed: () => _createSession());
  }

  Future<void> _sendEmail(int sessionIndex) async {
    Session session = _sessions[sessionIndex];
    String body = session.file.readAsStringSync();
    String subject = session.name;
    final Email email = Email(
      body: body,
      subject: subject,
      recipients: ['tyler@greaterscott.com'],
      attachmentPaths: [session.file.path],
    );

    String sendResponse;

    try {
      await FlutterEmailSender.send(email);
      sendResponse = 'Email sent!';
    } catch (error) {
      sendResponse = error.toString();
    }

    return showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: Text('Email Status'),
            content: Text(sendResponse),
            actions: <Widget>[
              FlatButton(
                textColor: Colors.blue,
                child: Text('Okay'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        });
  }

  Future<void> _showDeleteModal(int sessionIndex) async {
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Delete ${_sessions[sessionIndex].name}?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Deleting this session will permanently remove its data.'),
                Text('Are you sure you want to delete?'),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              textColor: Colors.red,
              child: Text('Delete'),
              onPressed: () {
                setState(() => _sessions.removeAt(sessionIndex));
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String get _activeSessionContent {
    try {
      return _activeSession.file.readAsStringSync();
    } catch (e) {
      return '';
    }
  }

  File moveFile(File sourceFile, String newPath) {
    try {
      return sourceFile.renameSync(newPath);
    } on FileSystemException catch (_) {
      final newFile = sourceFile.copySync(newPath);
      sourceFile.deleteSync();
      return newFile;
    }
  }

  void _syncFilenameToContent() {
    String content = _activeSession.file.readAsStringSync();
    String possibleFilename = content.split('\n').first.split('@').last.trim();

    if (!_activeSession.name.startsWith(possibleFilename)) {
      setState(() {
        _activeSession.file =
            moveFile(_activeSession.file, fullFilePath(possibleFilename));
      });
    }
  }

  void _writeSession(String content) =>
      _activeSession.file.writeAsString(content);

  void _sessionEditor() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      builder: (BuildContext context) {
        return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            child: TraindownEditor(
                content: _activeSessionContent, onChange: _writeSession),
            padding: EdgeInsets.only(top: 20.0));
      },
    ).whenComplete(() => _syncFilenameToContent());
  }

  Widget _sessionList() {
    // TODO: Consider only running this on dirty
    _sessions.sort((a, b) => b.name.compareTo(a.name));

    return Expanded(
        child: ListView.builder(
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              return Card(
                child: ListTile(
                  onTap: () {
                    _activeSession = _sessions[index];
                    _sessionEditor();
                  },
                  title: Text(_sessions[index].name),
                  trailing: PopupMenuButton<SessionMenuOption>(
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      tooltip: 'Session action menu',
                      onSelected: (SessionMenuOption action) {
                        switch (action) {
                          case SessionMenuOption.delete:
                            _showDeleteModal(index);
                            break;
                          case SessionMenuOption.email:
                            _sendEmail(index);
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<SessionMenuOption>>[
                            const PopupMenuItem<SessionMenuOption>(
                              value: SessionMenuOption.email,
                              child: Text('Send via email'),
                            ),
                            const PopupMenuItem<SessionMenuOption>(
                              value: SessionMenuOption.delete,
                              child: Text('Delete session'),
                            ),
                          ]),
                ),
              );
            }));
  }

  @override
  Widget build(BuildContext context) {
    if (_appData == null) _initAppData();

    return Align(
        alignment: Alignment.topLeft,
        child: SafeArea(
            left: true,
            top: true,
            right: true,
            bottom: true,
            minimum: const EdgeInsets.all(16.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[_createSessionButton(), _sessionList()])));
  }
}

class Transponder extends StatefulWidget {
  Transponder({Key key}) : super(key: key);

  @override
  _Transponder createState() => _Transponder();
}

class TraindownEditor extends StatefulWidget {
  final String content;
  final ValueChanged<String> onChange;

  TraindownEditor({Key key, this.content, this.onChange}) : super(key: key);

  @override
  _TraindownEditor createState() => _TraindownEditor();
}

class _TraindownEditor extends State<TraindownEditor> {
  TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void dispose() {
    _formatText();
    _controller.dispose();
    super.dispose();
  }

  void _addText(String addition) {
    addition = addition.isEmpty ? '' : addition;
    int start = _controller.selection.extentOffset;
    int end = _controller.selection.extentOffset + addition.length;
    _controller.value = _controller.value.copyWith(
        text: _controller.text.replaceRange(start, start, addition),
        selection: TextSelection.collapsed(offset: end));
    widget.onChange(_controller.value.text);
  }

  void _formatText() {
    Formatter formatter = Formatter.for_string(_controller.text);
    formatter.format();
    String text = formatter.output.toString();

    _controller.value = _controller.value.copyWith(
        text: text, selection: TextSelection.collapsed(offset: text.length));

    widget.onChange(_controller.value.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(10.0),
              child: EditableText(
                autocorrect: false,
                autofocus: true,
                backgroundCursorColor: Colors.blue,
                cursorColor: Colors.red,
                cursorWidth: 5,
                controller: _controller,
                enableSuggestions: false,
                expands: true,
                focusNode: FocusNode(),
                onChanged: (String text) => widget.onChange(text),
                scrollPadding: EdgeInsets.all(20.0),
                keyboardType: TextInputType.multiline,
                maxLines: null,
                style: TextStyle(
                    color: Colors.black.withOpacity(0.8),
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ButtonBar(
            alignment: MainAxisAlignment.center,
            buttonHeight: 10.0,
            buttonMinWidth: 10.0,
            buttonPadding: EdgeInsets.all(1.0),
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              FlatButton(
                child: Text('Meta'),
                onPressed: () => _addText('# '),
              ),
              FlatButton(
                child: Text('Colon'),
                onPressed: () => _addText(': '),
              ),
              FlatButton(
                child: Text('Note'),
                onPressed: () => _addText('* '),
              ),
              FlatButton(
                child: Text('Superset'),
                onPressed: () => _addText('+ '),
              ),
              FlatButton(
                child: Text('Date'),
                onPressed: () => _addText('@ '),
              ),
              FlatButton(
                child: Text('\u{1F9F9}'),
                onPressed: () => _formatText(),
              ),
            ],
          ),
        ]));
  }
}
