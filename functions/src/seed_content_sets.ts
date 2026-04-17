import * as admin from "firebase-admin";

import {seedContentSets} from "./content_sets";

async function run(): Promise<void> {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }

  const db = admin.firestore();

  for (const contentSet of seedContentSets) {
    const contentSetRef = db.doc(`content_sets/${contentSet.contentSetId}`);
    await contentSetRef.set(
      {
        contentSetId: contentSet.contentSetId,
        title: contentSet.title,
        description: contentSet.description,
        category: contentSet.category,
        level: contentSet.level,
        mode: contentSet.mode,
        locale: contentSet.locale,
        itemCount: contentSet.items.length,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    for (const item of contentSet.items) {
      await contentSetRef.collection("items").doc(item.itemId).set(
        {
          ...item,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }
  }

  process.stdout.write(
    `Seeded ${seedContentSets.length} content set(s) into Firestore.\n`,
  );
}

void run().catch((error) => {
  process.stderr.write(`Failed to seed content sets: ${String(error)}\n`);
  process.exitCode = 1;
});
