import Foundation
import SwiftData

extension SchemaV1 {
    /// Przedmiot szkolny z kolorem i ikoną.
    @Model
    public final class Subject {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var name: String = ""
        /// Nazwa koloru z palety przedmiotów w `DesignSystem` (np. `rose`).
        public var colorName: String = ""
        /// Nazwa symbolu SF Symbols.
        public var iconName: String = ""
        public var kindRaw: String = SubjectKind.general.rawValue
        /// Kolejność na listach.
        public var sortOrder: Int = 0

        @Relationship(deleteRule: .nullify, inverse: \Assessment.subject)
        public var assessments: [Assessment]? = []

        @Relationship(deleteRule: .nullify, inverse: \StudyMaterial.subject)
        public var materials: [StudyMaterial]? = []

        public var kind: SubjectKind {
            get { SubjectKind(rawValue: kindRaw) ?? .general }
            set { kindRaw = newValue.rawValue }
        }

        public init(
            name: String = "",
            kind: SubjectKind = .general,
            colorName: String = "",
            iconName: String = "",
            sortOrder: Int = 0
        ) {
            self.name = name
            self.kindRaw = kind.rawValue
            self.colorName = colorName
            self.iconName = iconName
            self.sortOrder = sortOrder
        }
    }

    /// Kartkówka, sprawdzian, praca klasowa lub inny termin.
    @Model
    public final class Assessment {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var kindRaw: String = AssessmentKind.test.rawValue
        public var date: Date = Date.now
        /// Zakres materiału.
        public var scope: String = ""
        public var statusRaw: String = AssessmentStatus.upcoming.rawValue
        /// Ocena wpisana po fakcie, np. „4+”.
        public var grade: String? = nil

        public var subject: Subject?

        @Relationship(deleteRule: .nullify, inverse: \StudyMaterial.assessments)
        public var materials: [StudyMaterial]? = []

        /// Sesje planu nauki należą do sprawdzianu i znikają razem z nim.
        @Relationship(deleteRule: .cascade, inverse: \StudySession.assessment)
        public var studySessions: [StudySession]? = []

        @Relationship(deleteRule: .nullify, inverse: \Quiz.assessment)
        public var quizzes: [Quiz]? = []

        @Relationship(deleteRule: .nullify, inverse: \ChatThread.assessment)
        public var chatThreads: [ChatThread]? = []

        public var kind: AssessmentKind {
            get { AssessmentKind(rawValue: kindRaw) ?? .other }
            set { kindRaw = newValue.rawValue }
        }

        public var status: AssessmentStatus {
            get { AssessmentStatus(rawValue: statusRaw) ?? .upcoming }
            set { statusRaw = newValue.rawValue }
        }

        public init(
            kind: AssessmentKind = .test,
            date: Date = .now,
            scope: String = "",
            status: AssessmentStatus = .upcoming,
            grade: String? = nil
        ) {
            self.kindRaw = kind.rawValue
            self.date = date
            self.scope = scope
            self.statusRaw = status.rawValue
            self.grade = grade
        }
    }

    /// Notatka, zdjęcie lub plik PDF.
    @Model
    public final class StudyMaterial {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var kindRaw: String = MaterialKind.note.rawValue
        public var title: String = ""
        /// Treść notatki tekstowej.
        public var content: String = ""
        /// Zdjęcie lub PDF; przechowywane poza bazą i synchronizowane jako zasób CloudKit.
        @Attribute(.externalStorage)
        public var fileData: Data? = nil
        /// Tekst rozpoznany na urządzeniu (Vision, PDFKit).
        public var recognizedText: String? = nil
        public var summary: String? = nil

        public var subject: Subject?
        public var assessments: [Assessment]? = []

        @Relationship(deleteRule: .nullify, inverse: \FlashcardDeck.material)
        public var flashcardDecks: [FlashcardDeck]? = []

        @Relationship(deleteRule: .nullify, inverse: \Quiz.material)
        public var quizzes: [Quiz]? = []

        @Relationship(deleteRule: .nullify, inverse: \ChatThread.material)
        public var chatThreads: [ChatThread]? = []

        public var kind: MaterialKind {
            get { MaterialKind(rawValue: kindRaw) ?? .note }
            set { kindRaw = newValue.rawValue }
        }

        public init(
            kind: MaterialKind = .note,
            title: String = "",
            content: String = "",
            fileData: Data? = nil
        ) {
            self.kindRaw = kind.rawValue
            self.title = title
            self.content = content
            self.fileData = fileData
        }
    }
}
