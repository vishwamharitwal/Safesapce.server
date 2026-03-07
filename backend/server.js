const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const crypto = require('crypto');

const app = express();
app.use(cors());

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
    methods: ['GET', 'POST']
  },
  pingTimeout: 60000,
  pingInterval: 25000
});

// Matchmaking Queues
const waitingQueues = {}; // { topic: { talkers: [], listeners: [] } }

// Active Rooms
const activeRooms = {}; // { roomId: { talker: {}, listener: {}, isAccepted: false } }

// User mapping (userId -> { socketId, currentRoomId, profile })
const userSessions = {};

function removeFromQueue(socketId) {
  for (const topic in waitingQueues) {
    waitingQueues[topic].talkers = waitingQueues[topic].talkers.filter(u => u.socketId !== socketId);
    waitingQueues[topic].listeners = waitingQueues[topic].listeners.filter(u => u.socketId !== socketId);
  }
}

function generateRoomId() {
  return crypto.randomBytes(8).toString('hex');
}

io.on('connection', (socket) => {
  console.log(`📡 New connection: ${socket.id}`);

  socket.on('register_user', (data) => {
    if (!data.userId) return;
    const userId = data.userId;
    console.log(`👤 Registering user: ${userId}`);

    if (!userSessions[userId]) {
      userSessions[userId] = { userId, profile: { nickname: 'Someone', avatar: '👤', rating: 5.0 } };
    }
    userSessions[userId].socketId = socket.id;

    // Auto-rejoin room if active
    const roomId = userSessions[userId].currentRoomId;
    if (roomId && activeRooms[roomId]) {
      socket.join(roomId);
      console.log(`🔄 User ${userId} rejoined room ${roomId}`);
      socket.emit('rejoined_room', { roomId });
    }
  });

  socket.on('find_match', (data) => {
    const { role, topic, userId, nickname, avatar, rating } = data;
    if (!userId) return;

    removeFromQueue(socket.id);

    // Update session profile
    if (userSessions[userId]) {
      userSessions[userId].profile = {
        nickname: nickname || userSessions[userId].profile.nickname,
        avatar: avatar || userSessions[userId].profile.avatar,
        rating: rating || userSessions[userId].profile.rating
      };
    }

    if (!waitingQueues[topic]) {
      waitingQueues[topic] = { talkers: [], listeners: [] };
    }

    const queue = waitingQueues[topic];
    let partnerEntry = null;

    // Find opposite role
    const targetQueue = role === 'talk' ? queue.listeners : queue.talkers;
    while (targetQueue.length > 0) {
      const entry = targetQueue.shift();
      if (io.sockets.sockets.has(entry.socketId)) {
        partnerEntry = entry;
        break;
      }
    }

    if (partnerEntry) {
      const roomId = `match_${generateRoomId()}`;

      const me = {
        socketId: socket.id,
        userId,
        nickname: nickname || 'Someone',
        avatar: avatar || '👤',
        rating: rating || 5.0
      };

      const them = {
        socketId: partnerEntry.socketId,
        userId: partnerEntry.userId,
        nickname: partnerEntry.nickname || 'Someone',
        avatar: partnerEntry.avatar || '👤',
        rating: partnerEntry.rating || 5.0
      };

      const roomData = {
        roomId,
        topic,
        talker: role === 'talk' ? me : them,
        listener: role === 'listen' ? me : them,
        isAccepted: false
      };

      activeRooms[roomId] = roomData;
      userSessions[me.userId].currentRoomId = roomId;
      userSessions[them.userId].currentRoomId = roomId;

      socket.join(roomId);
      const ps = io.sockets.sockets.get(partnerEntry.socketId);
      if (ps) ps.join(roomId);

      // Emit match_found
      socket.emit('match_found', {
        roomId,
        topic,
        partnerId: them.userId,
        partnerName: them.nickname,
        partnerAvatar: them.avatar,
        partnerRating: them.rating,
        isCaller: role === 'talk',
      });

      if (ps) {
        ps.emit('match_found', {
          roomId,
          topic,
          partnerId: me.userId,
          partnerName: me.nickname,
          partnerAvatar: me.avatar,
          partnerRating: me.rating,
          isCaller: role !== 'talk',
        });
      }
      console.log(`✅ Match Created: ${roomId}`);
    } else {
      const entry = { socketId: socket.id, userId, nickname, avatar, rating };
      if (role === 'talk') queue.talkers.push(entry);
      else queue.listeners.push(entry);
      socket.emit('waiting_for_match');
    }
  });

  socket.on('accept_match', (data) => {
    const { roomId } = data;
    if (activeRooms[roomId]) {
      activeRooms[roomId].isAccepted = true;
      socket.to(roomId).emit('partner_connected');
      console.log(`👍 Match accepted in ${roomId}`);
    }
  });

  socket.on('skip_match', (data) => {
    const { roomId } = data;
    if (activeRooms[roomId]) {
      socket.to(roomId).emit('match_skipped');
      const room = activeRooms[roomId];
      if (userSessions[room.talker.userId]) userSessions[room.talker.userId].currentRoomId = null;
      if (userSessions[room.listener.userId]) userSessions[room.listener.userId].currentRoomId = null;
      delete activeRooms[roomId];
    }
  });

  socket.on('webrtc_offer', (data) => {
    if (socket.rooms.has(data.roomId)) {
      socket.to(data.roomId).emit('webrtc_offer', data);
    }
  });

  socket.on('webrtc_answer', (data) => {
    if (socket.rooms.has(data.roomId)) {
      socket.to(data.roomId).emit('webrtc_answer', data);
    }
  });

  socket.on('webrtc_ice_candidate', (data) => {
    if (socket.rooms.has(data.roomId)) {
      socket.to(data.roomId).emit('webrtc_ice_candidate', data);
    }
  });

  socket.on('end_session', (data) => {
    const { roomId } = data;
    socket.to(roomId).emit('partner_left');
    socket.leave(roomId);
    if (activeRooms[roomId]) {
      const room = activeRooms[roomId];
      if (userSessions[room.talker.userId]) userSessions[room.talker.userId].currentRoomId = null;
      if (userSessions[room.listener.userId]) userSessions[room.listener.userId].currentRoomId = null;
      delete activeRooms[roomId];
    }
  });

  socket.on('disconnect', () => {
    console.log(`🛑 Disconnected: ${socket.id}`);
    removeFromQueue(socket.id);
    // Note: We don't delete the session here to allow re-registration
  });
});

setInterval(() => {
  for (const roomId in activeRooms) {
    const room = activeRooms[roomId];
    const tSocket = io.sockets.sockets.get(room.talker.socketId);
    const lSocket = io.sockets.sockets.get(room.listener.socketId);
    if (!tSocket && !lSocket) {
      delete activeRooms[roomId];
    }
  }
}, 300000);

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 Server on port ${PORT}`);
});
