import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'traindown_info.dart';

class Settings extends StatefulWidget {
  final SharedPreferences sharedPreferences;
  final Function? exportCallback;
  final Function? logsCallback;

  Settings(
      {Key? key,
      required this.sharedPreferences,
      this.exportCallback,
      this.logsCallback})
      : super(key: key);

  @override
  SettingsState createState() {
    return SettingsState();
  }
}

class SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Form(
      autovalidateMode: AutovalidateMode.always,
      onChanged: () {
        Form.of(primaryFocus!.context!)!.save();
      },
      child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                  child: Text('Settings',
                      style: TextStyle(
                          fontSize: 20.0, fontWeight: FontWeight.bold))),
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Unit like lbs or kgs',
                  labelText: 'Default session unit',
                ),
                // TODO: Constantize the keys
                initialValue:
                    widget.sharedPreferences.getString('defaultUnit') ?? 'lbs',
                onSaved: (String? value) {
                  if (value == null || value.isEmpty) {
                    value = 'lbs';
                  }
                  widget.sharedPreferences.setString('defaultUnit', value);
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'You need to specify a default unit like lbs or kgs';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'heavy@weights.com, you@rad.com',
                  labelText: 'Send to email(s)',
                ),
                initialValue:
                    widget.sharedPreferences.getString('sendToEmails'),
                onSaved: (String? value) {
                  if (value == null || value.isEmpty) {
                    widget.sharedPreferences.remove('sendToEmails');
                  } else {
                    widget.sharedPreferences.setString('sendToEmails', value);
                  }
                },
                validator: (value) {
                  if (value!.isNotEmpty &&
                      (!value.contains('@') || !value.contains('.'))) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              TraindownInfo(),
              Container(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(children: [
                    Text(
                        "The button below will ready an email that contains your entire Session history."),
                    ElevatedButton(
                        onPressed: widget.exportCallback as void Function()?,
                        child: Text('Export all data via email'))
                  ])),
              Container(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(children: [
                    Text(
                        "Should you have any issues, please send me an email containing your logs using the button below."),
                    ElevatedButton(
                        onPressed: widget.logsCallback as void Function()?,
                        child: Text('Email crash logs'))
                  ])),
            ],
          )),
    );
  }
}
