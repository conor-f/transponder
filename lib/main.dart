import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';

import 'session.dart';
import 'session_list.dart';
import 'traindown_editor.dart';
import 'traindown_viewer.dart';

void main() => runApp(MaterialApp(home: Scaffold(body: Transponder())));

class _Transponder extends State<Transponder> {
  Session _activeSession;
  Directory _appData;
  final List<Session> _sessions = [];

  String get _activeSessionContent {
    try {
      return _activeSession.file.readAsStringSync();
    } catch (e) {
      return '';
    }
  }

  Future<void> _copySession(int sessionIndex) async {
    String tmpFilename = DateTime.now().millisecondsSinceEpoch.toString();
    File tmpFile = File(fullFilePath(tmpFilename));
    String content = _sessions[sessionIndex].file.readAsStringSync();
    tmpFile.writeAsStringSync(content);
    Session session = Session(tmpFile, empty: false);
    setState(() => _sessions.add(session));
  }

  Future<void> _createSession() async {
    String tmpFilename = DateTime.now().millisecondsSinceEpoch.toString();
    Session session = Session(File(fullFilePath(tmpFilename)));
    setState(() {
      _sessions.add(session);
      _activeSession = session;
      _showSessionEditor();
    });
  }

  String fullFilePath(String filename) =>
      '${_appData.path}/$filename.traindown';

  Future<void> _initAppData() async {
    Directory directory = await getApplicationDocumentsDirectory();
    setState(() => _appData = directory);
    List<FileSystemEntity> files = directory.listSync();
    if (files.isNotEmpty) {
      files.forEach((file) => _sessions.add(Session(file, empty: false)));
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

  Widget _renderCreateSessionButton() {
    return FlatButton(
        textColor: Colors.blue,
        child: Text('Add new session'),
        onPressed: () => _createSession());
  }

  Widget _renderSessionList() {
    return SessionList(
        sessions: _sessions,
        onCopy: (index) => _copySession(index),
        onDelete: (index) => _showDeleteModal(index),
        onEmail: (index) => _sendEmail(index),
        onEdit: (index) {
          _activeSession = _sessions[index];
          _showSessionEditor();
        },
        onView: (index) {
          _activeSession = _sessions[index];
          _showSessionViewer();
        });
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
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              textColor: Colors.blue,
              child: Text('Cancel', style: TextStyle(fontSize: 16.0)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              textColor: Colors.red,
              child: Text('Delete',
                  style:
                      TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
              onPressed: () {
                if (_sessions[sessionIndex].teardown()) {
                  setState(() => _sessions.removeAt(sessionIndex));
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pop();
                  _showErrorModal('Could not delete session');
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showErrorModal(String message) async {
    return showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
              title: Text('An error occurred'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text('The following error occurred:\n'),
                    Text(message)
                  ],
                ),
              ),
              actions: <Widget>[
                FlatButton(
                    textColor: Colors.blue,
                    child: Text('Huh. Okay'),
                    onPressed: () => Navigator.of(context).pop())
              ]);
        });
  }

  void _showSessionEditor() {
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

  void _showSessionViewer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      builder: (BuildContext context) {
        return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            child: TraindownViewer(content: _activeSessionContent),
            padding: EdgeInsets.only(top: 20.0));
      },
    );
  }

  void _writeSession(String content) =>
      _activeSession.file.writeAsString(content);

  void _syncFilenameToContent() {
    String content = _activeSession.file.readAsStringSync();
    String possibleFilename = content.split('\n').first.split('@').last.trim();

    if (!_activeSession.filename.startsWith(possibleFilename)) {
      int existingSessionsCount = _sessions.fold(0, (count, session) {
        if (session.filename == '$possibleFilename.traindown') count++;
        return count;
      });

      if (existingSessionsCount > 0) {
        possibleFilename += '.$existingSessionsCount';
      }

      setState(() {
        _activeSession.file =
            moveFile(_activeSession.file, fullFilePath(possibleFilename));
        _sessions.sort((a, b) => b.filename.compareTo(a.filename));
      });
    }

    // NOTE: This just kicks the getters for _activeSession
    setState(() => _activeSession = _activeSession);
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
                children: <Widget>[
                  _renderCreateSessionButton(),
                  _renderSessionList()
                ])));
  }
}

class Transponder extends StatefulWidget {
  Transponder({Key key}) : super(key: key);

  @override
  _Transponder createState() => _Transponder();
}
