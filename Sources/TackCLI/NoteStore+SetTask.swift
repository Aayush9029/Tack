import TackKit

extension NoteStore {
    func setTask(_ reference: String, _ number: Int, done: Bool) throws -> Task {
        let note = try resolve(reference)
        let updated = try modify(note.id) { current in
            current.body = try NoteStore.setting(task: number, done: done, in: current.body)
        }
        return NoteStore.tasks(in: updated.body)[number - 1]
    }
}
