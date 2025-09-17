import React, { useEffect, useState } from "react";
import { firestoreDB } from "./firebase";
import {
  collection,
  getDocs,
  addDoc,
  updateDoc,
  deleteDoc,
  doc
} from "firebase/firestore";
import "./App.css";

function App() {
  const [groups, setGroups] = useState([]);
  const [newGroupName, setNewGroupName] = useState("");
  const [newStudentName, setNewStudentName] = useState("");
  const [selectedGroupId, setSelectedGroupId] = useState("");
  const [selectedStudent, setSelectedStudent] = useState(null);

  useEffect(() => {
    fetchGroups();
  }, []);

  async function fetchGroups() {
    const groupsSnap = await getDocs(collection(firestoreDB, "groups"));
    const groupsData = await Promise.all(
      groupsSnap.docs.map(async (groupDoc) => {
        const groupData = groupDoc.data();
        const studentsSnap = await getDocs(
          collection(firestoreDB, `groups/${groupDoc.id}/students`)
        );
        const students = studentsSnap.docs.map((studentDoc) => ({
          id: studentDoc.id,
          ...studentDoc.data()
        }));
        return { id: groupDoc.id, ...groupData, students };
      })
    );
    setGroups(groupsData);
  }

  async function createGroup() {
    if (!newGroupName) return alert("Enter group name");

    await addDoc(collection(firestoreDB, "groups"), {
      name: newGroupName,
      department: "CSE",
      breakTime: "12:00 PM",
      subjects: ["Math", "Physics"],
      maxStudents: 10
    });

    setNewGroupName("");
    fetchGroups();
  }

  async function deleteGroup(groupId) {
    await deleteDoc(doc(firestoreDB, "groups", groupId));
    if (selectedGroupId === groupId) {
      setSelectedGroupId("");
      setSelectedStudent(null);
    }
    fetchGroups();
  }

  async function addStudent() {
    if (!newStudentName || !selectedGroupId)
      return alert("Select group and enter student name");

    await addDoc(
      collection(firestoreDB, `groups/${selectedGroupId}/students`),
      {
        name: newStudentName,
        email: `${newStudentName.replace(" ", "").toLowerCase()}@example.com`
      }
    );

    setNewStudentName("");
    fetchGroups();
  }

  async function deleteStudent(groupId, studentId) {
    await deleteDoc(
      doc(firestoreDB, `groups/${groupId}/students`, studentId)
    );
    if (selectedStudent && selectedStudent.id === studentId) {
      setSelectedStudent(null);
    }
    fetchGroups();
  }

  const selectedGroup = groups.find(g => g.id === selectedGroupId);

  return (
    <div className="dashboard">
      <header className="header">
        <h1>Groups & Students Management Dashboard</h1>
      </header>

      <div className="main-content">
        <aside className="sidebar">
          <div className="form-section">
            <h3>Create New Group</h3>
            <div className="form-group">
              <input
                type="text"
                placeholder="Group Name (e.g., 2nd CSE-B)"
                value={newGroupName}
                onChange={(e) => setNewGroupName(e.target.value)}
                className="input-field"
              />
              <button onClick={createGroup} className="btn btn-primary">Create Group</button>
            </div>
          </div>

          <div className="form-section">
            <h3>Add New Student</h3>
            <div className="form-group">
              <select
                value={selectedGroupId}
                onChange={(e) => setSelectedGroupId(e.target.value)}
                className="input-field select-field"
              >
                <option value="">Select Group</option>
                {groups.map((group) => (
                  <option key={group.id} value={group.id}>
                    {group.name}
                  </option>
                ))}
              </select>
              <input
                type="text"
                placeholder="Student Name"
                value={newStudentName}
                onChange={(e) => setNewStudentName(e.target.value)}
                className="input-field"
              />
              <button onClick={addStudent} className="btn btn-primary">Add Student</button>
            </div>
          </div>
        </aside>

        <main className="main-panel">
          <section className="groups-section">
            <h2>Classes List</h2>
            <div className="groups-grid">
              {groups.map((group) => (
                <div key={group.id} className={`group-card ${selectedGroupId === group.id ? 'selected' : ''}`}>
                  <div className="card-header">
                    <h4>{group.name}</h4>
                    <span className="student-count">{group.students.length} Students</span>
                  </div>
                  <div className="card-actions">
                    <button 
                      onClick={() => {
                        setSelectedGroupId(group.id === selectedGroupId ? '' : group.id);
                        if (selectedGroupId !== group.id) setSelectedStudent(null);
                      }} 
                      className="btn btn-secondary"
                    >
                      {selectedGroupId === group.id ? 'Hide' : 'View Students'}
                    </button>
                    <button onClick={() => deleteGroup(group.id)} className="btn btn-danger">Delete Group</button>
                  </div>
                </div>
              ))}
            </div>
          </section>

          {selectedGroup && (
            <section className="students-section">
              <h3>Students in {selectedGroup.name}</h3>
              <div className="students-list">
                {selectedGroup.students.map((student) => (
                  <div 
                    key={student.id} 
                    className={`student-item ${selectedStudent?.id === student.id ? 'selected' : ''}`}
                    onClick={() => setSelectedStudent(selectedStudent?.id === student.id ? null : student)}
                  >
                    <span className="student-name">{student.name}</span>
                    <button 
                      onClick={(e) => {
                        e.stopPropagation();
                        deleteStudent(selectedGroup.id, student.id);
                      }}
                      className="btn btn-danger btn-small"
                    >
                      Delete
                    </button>
                  </div>
                ))}
              </div>
            </section>
          )}

          {selectedStudent && (
            <section className="student-details">
              <h3>Student Details</h3>
              <div className="details-card">
                <p><strong>Name:</strong> {selectedStudent.name}</p>
                <p><strong>Email:</strong> {selectedStudent.email}</p>
                <button 
                  onClick={() => setSelectedStudent(null)} 
                  className="btn btn-secondary"
                >
                  Close
                </button>
              </div>
            </section>
          )}
        </main>
      </div>
    </div>
  );
}

export default App;