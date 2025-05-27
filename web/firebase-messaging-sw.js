// web/firebase-messaging-sw.js

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBZj7uR381bcLdwfcBI_BozGVHhIAEa7xs',
  appId: '1:584140094374:web:3882066aa62b8d9e73ad67',
  messagingSenderId: '584140094374',
  projectId: 'guard-12345',
});

const messaging = firebase.messaging();
