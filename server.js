const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: process.env.CORS_ORIGIN || '*', 
    methods: ['GET', 'POST']
  }
});

// Matchmaking Queues
// Structure: { topicName: { talkers: [{socketId, userId}], listeners: [{socketId, userId}] } }
const waitingQueues = {};

// Active Rooms
// Structure: { roomId: { talker: socketId, listener: socketId, topic: topicName } }
const activeRooms = {};

function removeFromQueue(socketId) {
  for (const topic in waitingQueues) {
    waitingQueues[topic].talkers = waitingQueues[topic].talkers.filter(u => u.socketId !== socketId);
    waitingQueues[topic].listeners = waitingQueues[topic].listeners.filter(u => u.socketId !== socketId);
  }
}

io.on('connection', (socket) => {
  console.log(`User connected: ${socket.id}`);

  // 1. User wants to find a match
  socket.on('find_match', (data) => {
    // data: { role: 'talk' | 'listen', topic: 'Loneliness', nickname: '...', avatar: '...' }
    const { role, topic, userId, nickname, avatar } = data;

    if (!waitingQueues[topic]) {
      waitingQueues[topic] = { talkers: [], listeners: [] };
    }

    const queue = waitingQueues[topic];
    let matchedPartner = null;
    let partnerSocket = null;

    // Check if there is an opposite role waiting, skipping any dead sockets
    while (true) {
      if (role === 'talk' && queue.listeners.length > 0) {
        matchedPartner = queue.listeners.shift();
      } else if (role === 'listen' && queue.talkers.length > 0) {
        matchedPartner = queue.talkers.shift();
      } else {
        matchedPartner = null;
        break; // Queue is empty
      }

      partnerSocket = io.sockets.sockets.get(matchedPartner.socketId);
      if (partnerSocket) {
        break; // Valid live partner found!
      }
    }

    if (matchedPartner && partnerSocket) {
      // Create a new room
      const roomId = `room_${Date.now()}_${Math.random().toString(36).substring(7)}`;

      const roomData = {
        roomId,
        topic,
        talker: role === 'talk' ? socket.id : matchedPartner.socketId,
        listener: role === 'listen' ? socket.id : matchedPartner.socketId,
      };
      activeRooms[roomId] = roomData;

      // Make both sockets join the Socket.io room
      socket.join(roomId);
      const ps = io.sockets.sockets.get(matchedPartner.socketId);
      if (ps) {
        ps.join(roomId);
      }

      // Notify both that they found a match
      // The socket that just matched will act as the Caller
      socket.emit('match_found', {
        roomId,
        topic,
        partnerId: matchedPartner.userId,
        isCaller: true,
        message: 'You have been connected anonymously.'
      });
      if (ps) {
        ps.emit('match_found', {
          roomId,
          topic,
          partnerId: userId,
          isCaller: false,
          message: 'You have been connected anonymously.'
        });
      }

      console.log(`Matched ${socket.id} and ${matchedPartner.socketId} in ${roomId}`);
    } else {
      // No match found, add to queue
      if (role === 'talk') {
        queue.talkers.push({ socketId: socket.id, userId });
      } else {
        queue.listeners.push({ socketId: socket.id, userId });
      }
      socket.emit('waiting_for_match', { message: 'Waiting for someone to connect...' });
      console.log(`Added ${socket.id} to ${role} queue for topic: ${topic}`);
    }
  });

  // 2. WebRTC Signaling: Offer
  socket.on('webrtc_offer', (data) => {
    // data: { offer, roomId }
    socket.to(data.roomId).emit('webrtc_offer', {
      offer: data.offer,
      sender: socket.id
    });
  });

  // 3. WebRTC Signaling: Answer
  socket.on('webrtc_answer', (data) => {
    // data: { answer, roomId }
    socket.to(data.roomId).emit('webrtc_answer', {
      answer: data.answer,
      sender: socket.id
    });
  });

  // 4. WebRTC Signaling: ICE Candidate
  socket.on('webrtc_ice_candidate', (data) => {
    // data: { candidate, roomId }
    socket.to(data.roomId).emit('webrtc_ice_candidate', {
      candidate: data.candidate,
      sender: socket.id
    });
  });

  // 5. End Session / Leave Room
  socket.on('end_session', (data) => {
    const { roomId } = data;
    socket.to(roomId).emit('partner_left', { message: 'The other person ended the session.' });
    socket.leave(roomId);
    if (activeRooms[roomId]) {
      const partnerId = activeRooms[roomId].talker === socket.id
        ? activeRooms[roomId].listener
        : activeRooms[roomId].talker;

      const partnerSocket = io.sockets.sockets.get(partnerId);
      if (partnerSocket) {
        partnerSocket.leave(roomId);
      }
      delete activeRooms[roomId];
    }
  });

  // Disconnect handler
  socket.on('disconnect', () => {
    console.log(`User disconnected: ${socket.id}`);
    removeFromQueue(socket.id);

    // Check if user was in any active room and notify the partner
    for (const roomId in activeRooms) {
      if (activeRooms[roomId].talker === socket.id || activeRooms[roomId].listener === socket.id) {
        socket.to(roomId).emit('partner_left', { message: 'The other person disconnected.' });
        delete activeRooms[roomId];
      }
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Signaling server running on port ${PORT}`);
});
