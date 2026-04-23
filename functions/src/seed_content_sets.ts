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
        season: contentSet.season,
        version: contentSet.version,
        isActive: contentSet.isActive,
        supportsExpansion: contentSet.supportsExpansion,
        sentenceCountDaily: contentSet.category === "daily" ? contentSet.sentences.length : 0,
        sentenceCountMission: contentSet.category === "mission" ? contentSet.sentences.length : 0,
        itemCount: contentSet.sentences.length,
        sentenceItemCount: contentSet.sentences.length,
        wordItemCount: contentSet.words.length,
        itemCountByMode: {
          sentence_learning: contentSet.sentences.length,
          sentence_test: contentSet.sentences.length,
          flash_sentence_learning: contentSet.sentences.length,
          flash_sentence_test: contentSet.sentences.length,
          flash_word_learning: contentSet.words.length,
          flash_word_test: contentSet.words.length,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    for (const item of contentSet.sentences) {
      const payload = {
        ...item,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await contentSetRef.collection("sentences").doc(item.itemId).set(
        payload,
        {merge: true},
      );
    }

    for (const word of contentSet.words) {
      await contentSetRef.collection("words").doc(word.wordId).set(
        {
          ...word,
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
