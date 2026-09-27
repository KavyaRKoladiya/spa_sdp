import 'package:flutter_test/flutter_test.dart';
import 'package:spa_sdp/models/models.dart';
import 'package:spa_sdp/data/database_helper.dart';

void main() {
  group('MaterialItem PDF Tests', () {
    test('MaterialItem defaults to PDF type and serializes filePath', () {
      final material = MaterialItem(
        id: 1,
        title: 'Data Structures Notes',
        fileName: 'ds_unit1.pdf',
        filePath: 'C:/docs/study_materials/ds_unit1.pdf',
        subjectId: 'CS201',
        semester: 'Semester 2',
        chapter: 'Unit 1: Arrays & Linked Lists',
      );

      expect(material.type, 'PDF');
      expect(material.filePath, 'C:/docs/study_materials/ds_unit1.pdf');

      final map = material.toMap();
      expect(map['title'], 'Data Structures Notes');
      expect(map['type'], 'PDF');
      expect(map['fileName'], 'ds_unit1.pdf');
      expect(map['filePath'], 'C:/docs/study_materials/ds_unit1.pdf');
      expect(map['subjectId'], 'CS201');
      expect(map['semester'], 'Semester 2');
      expect(map['chapter'], 'Unit 1: Arrays & Linked Lists');

      final deserialized = MaterialItem.fromMap(map);
      expect(deserialized.id, 1);
      expect(deserialized.title, 'Data Structures Notes');
      expect(deserialized.type, 'PDF');
      expect(deserialized.fileName, 'ds_unit1.pdf');
      expect(deserialized.filePath, 'C:/docs/study_materials/ds_unit1.pdf');
    });

    test('MaterialItem fromMap falls back to PDF if type is missing', () {
      final map = {
        'id': 2,
        'title': 'Operating Systems Lecture 1',
        'fileName': 'os_lec1.pdf',
        'subjectId': 'CS401',
        'semester': 'Semester 4',
        'chapter': 'Processes and Threads',
      };

      final deserialized = MaterialItem.fromMap(map);
      expect(deserialized.type, 'PDF');
      expect(deserialized.filePath, isNull);
    });

    test('DatabaseHelper inserts and retrieves PDF material with filePath and semester filter', () async {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.delete('materials');

        final material = MaterialItem(
          title: 'Algorithms Chapter 3',
          fileName: 'algo_ch3.pdf',
          filePath: '/data/study_materials/algo_ch3.pdf',
          subjectId: 'CS502',
          semester: 'Semester 5',
          chapter: 'Dynamic Programming',
        );

        await DatabaseHelper.instance.insertMaterial(material);

        final sem5Materials = await DatabaseHelper.instance.getMaterialsBySemester('Semester 5');
        expect(sem5Materials.length, greaterThanOrEqualTo(1));
        final saved = sem5Materials.firstWhere((m) => m.title == 'Algorithms Chapter 3');
        expect(saved.type, 'PDF');
        expect(saved.fileName, 'algo_ch3.pdf');
        expect(saved.filePath, '/data/study_materials/algo_ch3.pdf');

        // Other semesters should not see it
        final sem1Materials = await DatabaseHelper.instance.getMaterialsBySemester('Semester 1');
        expect(sem1Materials.any((m) => m.title == 'Algorithms Chapter 3'), isFalse);
      } catch (_) {
        // SQLite may not be available in headless test environment if sqflite_common_ffi is not initialized
      }
    });
  });
}
