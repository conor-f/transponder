import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

class TraindownInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5.0),
            color: Theme.of(context).cardColor),
        margin: EdgeInsets.symmetric(vertical: 20.0),
        padding: EdgeInsets.all(20.0),
        child: Column(children: [
          Text(
              'For more information on how to write Traindown, check out the docs on the website:'),
          FlatButton(
              child: Text('https://traindown.com',
                  style: TextStyle(color: Theme.of(context).primaryColor)),
              onPressed: () => launch('https://traindown.com'))
        ]));
  }
}
