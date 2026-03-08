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
    origin: '*',
    methods: ['GET', 'POST']
  },
  pingTimeout: 60000,
  pingInterval: 25000,
  transports: ['websocket', 'polling']
});

// Matchmaking Queues
const waitingQueues = {};

// Active Rooms
const activeRooms = {};

// User persistent sessions (userId -> { socketId, currentRoomId, profile })
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
  console.log(`📡 Connection established: ${socket.id}`);

  socket.on('register_user', (data) => {
    if (!data.userId) return;
    const userId = data.userId;

    // Update session
    if (!userSessions[userId]) {
      userSessions[userId] = {
        userId,
        profile: {
          nickname: data.nickname || 'Someone',
          avatar: data.avatar || '👤',
          rating: data.rating || 5.0
        }
      };
    } else if (data.nickname) {
      // Update profile if fresh data received
      userSessions[userId].profile.nickname = data.nickname;
      userSessions[userId].profile.avatar = data.avatar;
      userSessions[userId].profile.rating = data.rating;
    }

    userSessions[userId].socketId = socket.id;
    console.log(`👤 User ${userSessions[userId].profile.nickname} [${userId}] registered (Socket: ${socket.id})`);

    // SESSION RECOVERY: Check if user was in a match
    const roomId = userSessions[userId].currentRoomId;
    if (roomId && activeRooms[roomId]) {
      socket.join(roomId);
      console.log(`🔄 User ${userId} auto-rejoined room ${roomId}`);

      const room = activeRooms[roomId];
      const partner = room.talker.userId === userId ? room.listener : room.talker;

      // Notify client they are back in an active match
      socket.emit('match_found', {
        roomId,
        topic: room.topic,
        partnerId: partner.userId,
        partnerName: partner.nickname,
        partnerAvatar: partner.avatar,
        partnerRating: partner.rating,
        isCaller: room.talker.userId === userId,
        isResync: true
      });

      // If it was already accepted, notify them to start session
      if (room.isAccepted) {
        socket.emit('partner_connected');
      }
    }
  });

  socket.on('find_match', (data) => {
    const { role, topic, userId, nickname, avatar, rating } = data;
    if (!userId) return;

    removeFromQueue(socket.id);

    // Save profile to session for reliability, prioritizing existing data if provided data is default
    if (!userSessions[userId]) {
      userSessions[userId] = { userId, profile: { nickname: 'Someone', avatar: '👤', rating: 5.0 } };
    }

    // Only update if client actually sent a valid new name
    if (nickname && nickname !== 'Someone' && nickname !== 'User') {
      userSessions[userId].profile.nickname = nickname;
    }
    if (avatar) {
      userSessions[userId].profile.avatar = avatar;
    }
    if (rating) {
      userSessions[userId].profile.rating = rating;
    }
    userSessions[userId].socketId = socket.id;

    if (!waitingQueues[topic]) {
      waitingQueues[topic] = { talkers: [], listeners: [] };
    }

    const queue = waitingQueues[topic];
    let partnerEntry = null;

    const targetQueue = role === 'talk' ? queue.listeners : queue.talkers;
    while (targetQueue.length > 0) {
      const entry = targetQueue.shift();
      // Check if partner is still online
      if (io.sockets.sockets.has(entry.socketId)) {
        partnerEntry = entry;
        break;
      }
    }

    if (partnerEntry) {
      const roomId = `match_${generateRoomId()}`;

      // Strict fallback to userSessions to guarantee actual nicknames are sent
      const myProfile = (userSessions[userId] && userSessions[userId].profile) || {};
      const partnerProfile = (userSessions[partnerEntry.userId] && userSessions[partnerEntry.userId].profile) || {};

      const meNick = (nickname && nickname !== 'Someone' && nickname !== 'User') ? nickname : myProfile.nickname;
      const themNick = (partnerEntry.nickname && partnerEntry.nickname !== 'Someone' && partnerEntry.nickname !== 'User') ? partnerEntry.nickname : partnerProfile.nickname;

      const me = {
        socketId: socket.id,
        userId: userId,
        nickname: meNick || 'Someone',
        avatar: avatar || myProfile.avatar || '👤',
        rating: rating || myProfile.rating || 5.0
      };

      const them = {
        socketId: partnerEntry.socketId,
        userId: partnerEntry.userId,
        nickname: themNick || 'Someone',
        avatar: partnerEntry.avatar || partnerProfile.avatar || '👤',
        rating: partnerEntry.rating || partnerProfile.rating || 5.0
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

      // Final Check: No null names
      const sanTalker = { ...roomData.talker, nickname: roomData.talker.nickname || 'Someone' };
      const sanListener = { ...roomData.listener, nickname: roomData.listener.nickname || 'Someone' };

      // Emit to Talker
      io.to(sanTalker.socketId).emit('match_found', {
        roomId,
        topic,
        partnerId: sanListener.userId,
        partnerName: sanListener.nickname,
        partnerAvatar: sanListener.avatar,
        partnerRating: sanListener.rating,
        isCaller: true,
      });

      // Emit to Listener
      io.to(sanListener.socketId).emit('match_found', {
        roomId,
        topic,
        partnerId: sanTalker.userId,
        partnerName: sanTalker.nickname,
        partnerAvatar: sanTalker.avatar,
        partnerRating: sanTalker.rating,
        isCaller: false,
      });

      console.log(`✅ Match Created: ${sanTalker.nickname} & ${sanListener.nickname} in ${roomId}`);
    } else {
      const entry = { socketId: socket.id, userId, nickname, avatar, rating };
      if (role === 'talk') queue.talkers.push(entry);
      else queue.listeners.push(entry);

      socket.emit('waiting_for_match');
      console.log(`⏳ ${nickname || 'User'} waiting in ${topic}`);
    }
  });

  socket.on('accept_match', (data) => {
    const { roomId } = data;
    if (activeRooms[roomId]) {
      activeRooms[roomId].isAccepted = true;
      const room = activeRooms[roomId];
      // Explicitly emit to both sockets directly by socket.id to guarantee delivery
      io.to(room.listener.socketId).emit('partner_connected');
      io.to(room.talker.socketId).emit('partner_connected');
      // Also emit to room as fallback
      socket.to(roomId).emit('partner_connected');
      console.log(`👍 Match accepted in ${roomId}. Notified listeners.`);
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

  // Signaling Relays
  socket.on('webrtc_offer', (data) => {
    if (socket.rooms.has(data.roomId)) socket.to(data.roomId).emit('webrtc_offer', data);
  });
  socket.on('webrtc_answer', (data) => {
    if (socket.rooms.has(data.roomId)) socket.to(data.roomId).emit('webrtc_answer', data);
  });
  socket.on('webrtc_ice_candidate', (data) => {
    if (socket.rooms.has(data.roomId)) socket.to(data.roomId).emit('webrtc_ice_candidate', data);
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

    // If they disconnect during a pending match, skip it automatically so partner isn't stuck
    for (const roomId in activeRooms) {
      const room = activeRooms[roomId];
      if (room.talker.socketId === socket.id || room.listener.socketId === socket.id) {
        if (!room.isAccepted) {
          console.log(`⏳ Auto-skipping match ${roomId} due to disconnect`);
          socket.to(roomId).emit('match_skipped');
          if (userSessions[room.talker.userId]) userSessions[room.talker.userId].currentRoomId = null;
          if (userSessions[room.listener.userId]) userSessions[room.listener.userId].currentRoomId = null;
          delete activeRooms[roomId];
        } else {
          // If already accepted, maybe notify partner_left
          socket.to(roomId).emit('partner_left');
        }
      }
    }
  });
});

// Housekeeping
setInterval(() => {
  for (const roomId in activeRooms) {
    const room = activeRooms[roomId];
    const tSocket = io.sockets.sockets.get(room.talker.socketId);
    const lSocket = io.sockets.sockets.get(room.listener.socketId);
    if (!tSocket && !lSocket) {
      console.log(`[Cleanup] Removing ghost room ${roomId}`);
      delete activeRooms[roomId];
    }
  }
}, 300000);

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 Signaling server running on port ${PORT}`);
});
