import 'package:flutter/material.dart';
import 'firestore_cache.dart';

class FirestoreCacheRebuilder extends StatelessWidget {
  final Widget child;

  const FirestoreCacheRebuilder({Key? key, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: FirestoreQueryCache.instance.changes,
      builder: (context, snapshot) {
        return child;
      },
    );
  }
}
