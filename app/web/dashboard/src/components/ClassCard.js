import React from "react";

function ClassCard({ group, onClick, onDelete }) {
  return (
    <div className="class-card" onClick={onClick}>
      <div className="class-card-header">
        <h3>{group.name}</h3>
        <span className="student-count">
          {group.students ? group.students.length : 0}/{group.strength} Students
        </span>
      </div>
      
      <div className="class-details">
        <p><strong>Department:</strong> {group.department}</p>
        <p><strong>Subjects:</strong> {Array.isArray(group.subjects) ? group.subjects.join(", ") : group.subjects}</p>
        <p><strong>Teacher:</strong> {group.teacherName}</p>
      </div>
      
      <div className="class-card-actions">
        <button 
          className="btn-danger" 
          onClick={(e) => {
            e.stopPropagation();
            onDelete();
          }}
        >
          Delete Class
        </button>
      </div>
    </div>
  );
}

export default ClassCard;