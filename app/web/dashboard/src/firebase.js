import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyD3ads7fAU3I7WdMLaEB2W5wLlS-O8h31g",
  authDomain: "geoat-7.firebaseapp.com",
  projectId: "geoat-7",
  storageBucket: "geoat-7.firebasestorage.app",
  messagingSenderId: "894800243617",
  appId: "1:894800243617:web:7e946d0fbcd35bd5b9f9e0",
  measurementId: "G-CMDQ8Z5T90"
};

const app = initializeApp(firebaseConfig);
export const firestoreDB = getFirestore(app);
