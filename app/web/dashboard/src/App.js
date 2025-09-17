import React, { useEffect, useState } from "react";
import { firestoreDB } from "./firebase";
import {
  collection,
  getDocs,
  addDoc,
  deleteDoc,
  doc
} from "firebase/firestore";
import ClassCard from "./components/ClassCard";
import StudentList from "./components/StudentList";
import "./styles/Dashboard.css";

function App() {
  const [groups, setGroups] = useState([]);
  const [newClassName, setNewClassName] = useState("");
  const [newDepartment, setNewDepartment] = useState("");
  const [newSubjects, setNewSubjects] = useState("");
  const [newStrength, setNewStrength] = useState("");
  const [newTeacherName, setNewTeacherName] = useState("");
  const [view, setView] = useState("classes");
  const [selectedGroup, setSelectedGroup] = useState(null);
  const [showCreateForm, setShowCreateForm] = useState(false);

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
    if (!newClassName) return alert("Enter class name");
    if (!newDepartment) return alert("Enter department");
    if (!newSubjects) return alert("Enter subjects");
    if (!newStrength || isNaN(newStrength)) return alert("Enter valid strength number");
    if (!newTeacherName) return alert("Enter teacher name");

    // Convert subjects string to array
    const subjectsArray = newSubjects.split(',').map(subject => subject.trim());

    await addDoc(collection(firestoreDB, "groups"), {
      name: newClassName,
      department: newDepartment,
      subjects: subjectsArray,
      strength: parseInt(newStrength),
      teacherName: newTeacherName,
      students: [] // Initialize empty students array
    });

    // Reset form fields
    setNewClassName("");
    setNewDepartment("");
    setNewSubjects("");
    setNewStrength("");
    setNewTeacherName("");
    setShowCreateForm(false);
    
    fetchGroups();
  }

  async function deleteGroup(groupId) {
    if (window.confirm("Are you sure you want to delete this class? All students in this class will also be deleted.")) {
      await deleteDoc(doc(firestoreDB, "groups", groupId));
      fetchGroups();
    }
  }

  const handleClassClick = (group) => {
    setSelectedGroup(group);
    setView("students");
  };

  const handleBackToClasses = () => {
    setView("classes");
    setSelectedGroup(null);
  };

  return (
    <div className="dashboard-container">
      <header className="dashboard-header">
        <h1>Classroom Management Dashboard</h1>
      </header>

      {view === "classes" ? (
        <div className="classes-view">
          <div className="action-panel">
            <div className="create-group-section">
              <div className="section-header">
                <h2>Class Management</h2>
                <button 
                  className={`btn-toggle ${showCreateForm ? 'active' : ''}`}
                  onClick={() => setShowCreateForm(!showCreateForm)}
                >
                  {showCreateForm ? 'Cancel' : 'Create New Class'}
                </button>
              </div>
              
              {showCreateForm && (
                <div className="create-group-form">
                  <h3>Create New Class</h3>
                  <div className="form-grid">
                    <div className="form-group">
                      <label>Class Name *</label>
                      <input
                        type="text"
                        placeholder="e.g., CS101"
                        value={newClassName}
                        onChange={(e) => setNewClassName(e.target.value)}
                      />
                    </div>
                    <div className="form-group">
                      <label>Department *</label>
                      <input
                        type="text"
                        placeholder="e.g., Computer Science"
                        value={newDepartment}
                        onChange={(e) => setNewDepartment(e.target.value)}
                      />
                    </div>
                    <div className="form-group">
                      <label>Subjects (comma separated) *</label>
                      <input
                        type="text"
                        placeholder="e.g., Math, Physics, Programming"
                        value={newSubjects}
                        onChange={(e) => setNewSubjects(e.target.value)}
                      />
                    </div>
                    <div className="form-group">
                      <label>Strength *</label>
                      <input
                        type="number"
                        placeholder="e.g., 30"
                        value={newStrength}
                        onChange={(e) => setNewStrength(e.target.value)}
                      />
                    </div>
                    <div className="form-group">
                      <label>Teacher Name *</label>
                      <input
                        type="text"
                        placeholder="e.g., Dr. Smith"
                        value={newTeacherName}
                        onChange={(e) => setNewTeacherName(e.target.value)}
                      />
                    </div>
                  </div>
                  <button className="btn-primary" onClick={createGroup}>
                    Create Class
                  </button>
                </div>
              )}
            </div>
          </div>

          <div className="classes-section">
            <h2>Your Classes</h2>
            <div className="classes-grid">
              {groups.map((group) => (
                <ClassCard
                  key={group.id}
                  group={group}
                  onClick={() => handleClassClick(group)}
                  onDelete={() => deleteGroup(group.id)}
                />
              ))}
            </div>
          </div>
        </div>
      ) : (
        <StudentList
          group={selectedGroup}
          onBack={handleBackToClasses}
        />
      )}
    </div>
  );
}

export default App;