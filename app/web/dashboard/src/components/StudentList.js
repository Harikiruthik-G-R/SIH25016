// components/StudentList.js
import React, { useState, useEffect } from "react";
import { firestoreDB } from "../firebase";
import { collection, addDoc, deleteDoc, doc, getDocs, onSnapshot } from "firebase/firestore";

function StudentList({ group, onBack }) {
  const [newStudentName, setNewStudentName] = useState("");
  const [newStudentRollNo, setNewStudentRollNo] = useState("");
  const [newStudentEmail, setNewStudentEmail] = useState("");
  const [newStudentMobile, setNewStudentMobile] = useState("");
  const [existingRollNumbers, setExistingRollNumbers] = useState([]);
  const [existingEmails, setExistingEmails] = useState([]);
  const [errors, setErrors] = useState({});
  const [students, setStudents] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Set up real-time listener for students
    const unsubscribe = onSnapshot(
      collection(firestoreDB, `groups/${group.id}/students`),
      (snapshot) => {
        const studentsData = snapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        }));
        setStudents(studentsData);
        setLoading(false);
        
        // Update existing data for validation
        const rollNumbers = studentsData.map(student => student.rollNo);
        const emails = studentsData.map(student => student.email.toLowerCase());
        setExistingRollNumbers(rollNumbers);
        setExistingEmails(emails);
      },
      (error) => {
        console.error("Error fetching students: ", error);
        setLoading(false);
      }
    );

    // Clean up listener on unmount
    return () => unsubscribe();
  }, [group.id]);

  function validateForm() {
    const newErrors = {};
    
    // Check if roll number already exists
    if (existingRollNumbers.includes(newStudentRollNo)) {
      newErrors.rollNo = "Roll number already exists";
    }
    
    // Check if email already exists
    if (existingEmails.includes(newStudentEmail.toLowerCase())) {
      newErrors.email = "Email already exists";
    }
    
    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (newStudentEmail && !emailRegex.test(newStudentEmail)) {
      newErrors.email = "Invalid email format";
    }
    
    // Validate mobile number (basic validation)
    const mobileRegex = /^[0-9]{10}$/;
    if (newStudentMobile && !mobileRegex.test(newStudentMobile)) {
      newErrors.mobile = "Mobile number must be 10 digits";
    }
    
    // Check required fields
    if (!newStudentName) newErrors.name = "Name is required";
    if (!newStudentRollNo) newErrors.rollNo = "Roll number is required";
    if (!newStudentEmail) newErrors.email = "Email is required";
    if (!newStudentMobile) newErrors.mobile = "Mobile number is required";
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }

  async function addStudent() {
    if (!validateForm()) return;
    
    try {
      await addDoc(
        collection(firestoreDB, `groups/${group.id}/students`),
        {
          name: newStudentName,
          rollNo: newStudentRollNo,
          email: newStudentEmail.toLowerCase(),
          mobile: newStudentMobile,
          department: group.department
        }
      );

      // Reset form fields
      setNewStudentName("");
      setNewStudentRollNo("");
      setNewStudentEmail("");
      setNewStudentMobile("");
      setErrors({});
    } catch (error) {
      console.error("Error adding student: ", error);
      alert("Error adding student. Please try again.");
    }
  }

  // Delete student function
  async function deleteStudent(studentId) {
    if (window.confirm("Are you sure you want to delete this student?")) {
      try {
        await deleteDoc(
          doc(firestoreDB, `groups/${group.id}/students`, studentId)
        );
      } catch (error) {
        console.error("Error deleting student: ", error);
        alert("Error deleting student. Please try again.");
      }
    }
  }

  if (loading) {
    return (
      <div className="students-view">
        <div className="students-header">
          <button className="btn-back" onClick={onBack}>
            ← Back to Classes
          </button>
          <h2>{group.name} - Students</h2>
          <p>Loading students...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="students-view">
      <div className="students-header">
        <button className="btn-back" onClick={onBack}>
          ← Back to Classes
        </button>
        <h2>{group.name} - Students</h2>
        <div className="class-info">
          <p><strong>Department:</strong> {group.department}</p>
          <p><strong>Break Time:</strong> {group.breakTime}</p>
          <p><strong>Subjects:</strong> {group.subjects.join(", ")}</p>
          <p><strong>Max Students:</strong> {group.maxStudents}</p>
        </div>
      </div>

      <div className="add-student-form">
        <h3>Add New Student</h3>
        <div className="form-grid">
          <div className="form-group">
            <label>Name *</label>
            <input
              type="text"
              placeholder="Student Name"
              value={newStudentName}
              onChange={(e) => setNewStudentName(e.target.value)}
              className={errors.name ? "error" : ""}
            />
            {errors.name && <span className="error-text">{errors.name}</span>}
          </div>
          <div className="form-group">
            <label>Roll Number *</label>
            <input
              type="text"
              placeholder="Roll Number"
              value={newStudentRollNo}
              onChange={(e) => setNewStudentRollNo(e.target.value)}
              className={errors.rollNo ? "error" : ""}
            />
            {errors.rollNo && <span className="error-text">{errors.rollNo}</span>}
          </div>
          <div className="form-group">
            <label>Email *</label>
            <input
              type="email"
              placeholder="Email Address"
              value={newStudentEmail}
              onChange={(e) => setNewStudentEmail(e.target.value)}
              className={errors.email ? "error" : ""}
            />
            {errors.email && <span className="error-text">{errors.email}</span>}
          </div>
          <div className="form-group">
            <label>Mobile *</label>
            <input
              type="tel"
              placeholder="Mobile Number"
              value={newStudentMobile}
              onChange={(e) => setNewStudentMobile(e.target.value)}
              className={errors.mobile ? "error" : ""}
            />
            {errors.mobile && <span className="error-text">{errors.mobile}</span>}
          </div>
        </div>
        <button className="btn-primary" onClick={addStudent}>
          Add Student
        </button>
      </div>

      <div className="students-list">
        <h3>Student Roster ({students.length}/{group.maxStudents})</h3>
        {students.length === 0 ? (
          <p className="no-students">No students added yet.</p>
        ) : (
          <div className="students-table">
            <table>
              <thead>
                <tr>
                  <th>Roll No</th>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Mobile</th>
                  <th>Department</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {students.map((student) => (
                  <tr key={student.id}>
                    <td>{student.rollNo || "N/A"}</td>
                    <td>{student.name || "N/A"}</td>
                    <td>{student.email || "N/A"}</td>
                    <td>{student.mobile || "N/A"}</td>
                    <td>{student.department || group.department}</td>
                    <td>
                      <button 
                        className="btn-danger"
                        onClick={() => deleteStudent(student.id)}
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

export default StudentList;