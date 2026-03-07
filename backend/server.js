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

// Online Users mapping (userId -> socketId) for direct calls
const onlineUsers = {};

function removeFromQueue(socketId) {
  for (const topic in waitingQueues) {
    waitingQueues[topic].talkers = waitingQueues[topic].talkers.filter(u => u.socketId !== socketId);
    waitingQueues[topic].listeners = waitingQueues[topic].listeners.filter(u => u.socketId !== socketId);
  }
}

io.on('connection', (socket) => {
  console.log(`User connected: ${socket.id}`);

  // Register user id mapped to socket for direct calling presence
  socket.on('register_user', (data) => {
    if (data.userId) {
      onlineUsers[data.userId] = socket.id;
      console.log(`Registered user ${data.userId} with socket ${socket.id}`);
    }
  });

  // 1. User wants to find a match
  socket.on('find_match', (data) => {
    // data: { role: 'talk' | 'listen', topic: 'Loneliness', nickname: '...', avatar: '...', rating: ... }
    const { role, topic, userId, nickname, avatar, rating } = data;

    removeFromQueue(socket.id);

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
      const roomId = `match_${generateRoomId()}`;

      const roomData = {
        roomId,
        topic,
        talker: {
          socketId: role === 'talk' ? socket.id : matchedPartner.socketId,
          userId: role === 'talk' ? userId : matchedPartner.userId,
          nickname: role === 'talk' ? nickname : (matchedPartner.nickname || 'Someone'),
          avatar: role === 'talk' ? avatar : (matchedPartner.avatar || '👤'),
          rating: role === 'talk' ? rating : (matchedPartner.rating || 0.0)
        },
        listener: {
          socketId: role === 'listen' ? socket.id : matchedPartner.socketId,
          userId: role === 'listen' ? userId : matchedPartner.userId,
          nickname: role === 'listen' ? nickname : (matchedPartner.nickname || 'Someone'),
          avatar: role === 'listen' ? avatar : (matchedPartner.avatar || '👤'),
          rating: role === 'listen' ? rating : (matchedPartner.rating || 0.0)
        },
        isAccepted: false
      };

      activeRooms[roomId] = roomData;

      // Scalability: Both join immediately for signaling sync
      socket.join(roomId);
      if (partnerSocket) partnerSocket.join(roomId);

      // Notify both about the match
      socket.emit('match_found', {
        roomId,
        topic,
        partnerId: roomData.talker.socketId === socket.id ? roomData.listener.userId : roomData.talker.userId,
        partnerName: roomData.talker.socketId === socket.id ? roomData.listener.nickname : roomData.talker.nickname,
        partnerAvatar: roomData.talker.socketId === socket.id ? roomData.listener.avatar : roomData.talker.avatar,
        partnerRating: roomData.talker.socketId === socket.id ? roomData.listener.rating : roomData.talker.rating,
        isCaller: role === 'talk',
        message: 'A match was found. Review the profile to connect.'
      });

      if (partnerSocket) {
        partnerSocket.emit('match_found', {
          roomId,
          topic,
          partnerId: roomData.listener.socketId === partnerSocket.id ? roomData.talker.userId : roomData.listener.userId,
          partnerName: roomData.listener.socketId === partnerSocket.id ? roomData.talker.nickname : roomData.listener.nickname,
          partnerAvatar: roomData.listener.socketId === partnerSocket.id ? roomData.talker.avatar : roomData.listener.avatar,
          partnerRating: roomData.listener.socketId === partnerSocket.id ? roomData.talker.rating : roomData.listener.rating,
          isCaller: role !== 'talk',
          message: 'Someone is viewing your profile...'
        });
      }

      console.log(`✅ Match Created: ${roomData.talker.nickname} & ${roomData.listener.nickname} in ${roomId}`);
    } else {
      // No match found, add to queue with profile info
      const userEntry = { socketId: socket.id, userId, nickname, avatar, rating };
      if (role === 'talk') {
        queue.talkers.push(userEntry);
      } else {
        queue.listeners.push(userEntry);
      }
      socket.emit('waiting_for_match', { message: 'Waiting for someone to connect...' });
      console.log(`⏳ User ${nickname || 'User'} waiting for ${role === 'talk' ? 'listener' : 'talker'} in ${topic}`);
    }
  });

  // 1d. Cancel Matchmaking
  socket.on('cancel_matchmaking', () => {
    removeFromQueue(socket.id);
  });

  // 1b. Accept Match
  socket.on('accept_match', (data) => {
    const { roomId } = data;
    const room = activeRooms[roomId];
    if (!room) {
      console.log(`⚠️ Accept failed: Room ${roomId} not found`);
      return;
    }

    room.isAccepted = true;
    console.log(`✅ Match accepted by ${socket.id} in ${roomId}`);
    socket.to(roomId).emit('partner_connected', { message: 'Partner joined the chat!' });
  });

  // 1c. Skip Match
  socket.on('skip_match', (data) => {
    const { roomId } = data;
    const room = activeRooms[roomId];
    if (!room) return;

    console.log(`❌ Match skipped by ${socket.id} in ${roomId}`);
    socket.to(roomId).emit('match_skipped', { message: 'Match was skipped.' });
    delete activeRooms[roomId];
  });

  // 2. WebRTC Signaling: Offer
  socket.on('webrtc_offer', (data) => {
    if (!socket.rooms.has(data.roomId)) return;
    socket.to(data.roomId).emit('webrtc_offer', {
      offer: data.offer,
      sender: socket.id
    });
  });

  // ... rest of signaling remains same ...
  socket.on('webrtc_answer', (data) => {
    if (!socket.rooms.has(data.roomId)) return;
    socket.to(data.roomId).emit('webrtc_answer', {
      answer: data.answer,
      sender: socket.id
    });
  });

  socket.on('webrtc_ice_candidate', (data) => {
    if (!socket.rooms.has(data.roomId)) return;
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
    delete activeRooms[roomId];
  });

  // 6. Direct Calling: Initiate Call
  socket.on('call_direct', (data) => {
    const targetSocketId = onlineUsers[data.targetUserId];
    if (targetSocketId && io.sockets.sockets.get(targetSocketId)) {
      io.to(targetSocketId).emit('incoming_call', {
        callerId: data.callerId,
        callerSocketId: socket.id,
        callerName: data.callerName || 'Someone',
        callerAvatar: data.callerAvatar || '👤'
      });
    } else {
      socket.emit('call_failed', { message: 'User is currently offline.' });
    }
  });

  // 7. Direct Calling: Accept Call
  socket.on('accept_call', (data) => {
    const callerSocket = io.sockets.sockets.get(data.callerSocketId);
    if (callerSocket) {
      const roomId = `direct_${generateRoomId()}`;
      activeRooms[roomId] = {
        roomId,
        topic: 'Direct Connection',
        talker: { socketId: data.callerSocketId, userId: 'caller' },
        listener: { socketId: socket.id, userId: 'receiver' },
        isAccepted: true
      };

      socket.join(roomId);
      callerSocket.join(roomId);

      callerSocket.emit('match_found', {
        roomId,
        topic: 'Direct Connection',
        partnerId: socket.id,
        isCaller: true,
        message: 'Chat call accepted!'
      });

      socket.emit('match_found', {
        roomId,
        topic: 'Direct Connection',
        partnerId: data.callerSocketId,
        isCaller: false,
        message: 'Chat call accepted!'
      });
    }
  });

  socket.on('decline_call', (data) => {
    io.to(data.callerSocketId).emit('call_declined', { message: 'Call was declined.' });
  });

  socket.on('disconnect', () => {
    console.log(`User disconnected: ${socket.id}`);
    removeFromQueue(socket.id);

    for (const roomId in activeRooms) {
      const room = activeRooms[roomId];
      if (room.talker.socketId === socket.id || room.listener.socketId === socket.id) {
        socket.to(roomId).emit('partner_left', { message: 'The other person disconnected.' });
        delete activeRooms[roomId];
      }
    }

    for (const userId in onlineUsers) {
      if (onlineUsers[userId] === socket.id) {
        delete onlineUsers[userId];
        break;
      }
    }
  });
});

const crypto = require('crypto');
function generateRoomId() {
  return crypto.randomBytes(8).toString('hex');
}

setInterval(() => {
  let cleaned = 0;
  for (const roomId in activeRooms) {
    const room = activeRooms[roomId];
    const tSocket = io.sockets.sockets.get(room.talker.socketId);
    const lSocket = io.sockets.sockets.get(room.listener.socketId);

    if (!tSocket && !lSocket) {
      delete activeRooms[roomId];
      cleaned++;
    }
  }
  if (cleaned > 0) console.log(`[Cleanup] Removed ${cleaned} ghost rooms.`);
}, 1000 * 60 * 5);

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Signaling server running on port ${PORT}`);
});
