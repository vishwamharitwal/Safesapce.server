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
      const roomId = `room_${Date.now()}_${Math.random().toString(36).substring(7)}`;

      const roomData = {
        roomId,
        topic,
        talker: role === 'talk' ? { socketId: socket.id, userId: userId, accepted: false } : { socketId: matchedPartner.socketId, userId: matchedPartner.userId, accepted: false },
        listener: role === 'listen' ? { socketId: socket.id, userId: userId, accepted: false } : { socketId: matchedPartner.socketId, userId: matchedPartner.userId, accepted: false },
      };

      activeRooms[roomId] = roomData;

      // Notify both about the match but don't start call yet
      socket.emit('match_found', {
        roomId,
        topic,
        partnerId: matchedPartner.userId,
        partnerName: 'User', // In a real app, fetch from metadata or DB
        partnerAvatar: '👤',
        isCaller: true, // Talker will initiate WebRTC offer once accepted
        message: 'A match was found. Review the profile to connect.'
      });

      const ps = io.sockets.sockets.get(matchedPartner.socketId);
      if (ps) {
        ps.emit('match_found', {
          roomId,
          topic,
          partnerId: userId,
          partnerName: 'User',
          partnerAvatar: '👤',
          isCaller: false,
          message: 'Someone is viewing your profile...'
        });
      }

      console.log(`Potential Match: ${socket.id} and ${matchedPartner.socketId} in ${roomId}`);
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

  // 1b. Accept Match
  socket.on('accept_match', (data) => {
    const { roomId } = data;
    const room = activeRooms[roomId];
    if (!room) return;

    // Join the room for signaling
    socket.join(roomId);
    console.log(`User ${socket.id} accepted match in ${roomId}`);

    // Notify the other user that talker has connected
    socket.to(roomId).emit('partner_connected', { message: 'Partner joined the chat!' });
  });

  // 1c. Skip Match
  socket.on('skip_match', (data) => {
    const { roomId } = data;
    const room = activeRooms[roomId];
    if (!room) return;

    console.log(`User ${socket.id} skipped match in ${roomId}`);

    // Notify listener that they were skipped and re-queue them
    const listenerSocketId = room.listener.socketId;
    const listenerSocket = io.sockets.sockets.get(listenerSocketId);
    if (listenerSocket) {
      listenerSocket.emit('match_skipped', { message: 'Match was skipped by talker. Re-queueing...' });
      // Logic for re-queueing listener would go here, or we let client re-send find_match
    }

    delete activeRooms[roomId];
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

  // 6. Direct Calling: Initiate Call
  socket.on('call_direct', (data) => {
    // data: { targetUserId, callerId, callerName, callerAvatar }
    console.log(`Call Direct Attempt: From ${socket.id} to ${data.targetUserId}`);
    console.log(`Current Online Users:`, Object.keys(onlineUsers));

    const targetSocketId = onlineUsers[data.targetUserId];

    if (targetSocketId && io.sockets.sockets.get(targetSocketId)) {
      // Partner is online, send them an incoming call event
      console.log(`Routing call to socket: ${targetSocketId}`);
      io.to(targetSocketId).emit('incoming_call', {
        callerId: data.callerId,
        callerSocketId: socket.id,
        callerName: data.callerName || 'Someone',
        callerAvatar: data.callerAvatar || '👤'
      });
    } else {
      // Partner offline
      console.log(`Call Failed: User ${data.targetUserId} is offline or socket dead.`);
      socket.emit('call_failed', { message: 'User is currently offline.' });
    }
  });

  // 7. Direct Calling: Accept Call
  socket.on('accept_call', (data) => {
    // data: { callerSocketId, receiverUserId }
    const callerSocket = io.sockets.sockets.get(data.callerSocketId);
    if (callerSocket) {
      const roomId = `direct_${Date.now()}_${Math.random().toString(36).substring(7)}`;

      activeRooms[roomId] = {
        roomId,
        topic: 'Direct Connection',
        talker: data.callerSocketId, // The person who initiated
        listener: socket.id, // The person accepting
      };

      socket.join(roomId);
      callerSocket.join(roomId);

      // Caller is the offerer
      callerSocket.emit('match_found', {
        roomId,
        topic: 'Direct Connection',
        partnerId: data.receiverUserId,
        isCaller: true,
        message: 'Chat call accepted!'
      });

      // Reciever answers the offer
      socket.emit('match_found', {
        roomId,
        topic: 'Direct Connection',
        partnerId: data.callerSocketId, // we just need an ID, could be UUID
        isCaller: false,
        message: 'Chat call accepted!'
      });
      console.log(`Direct call room created: ${roomId}`);
    } else {
      socket.emit('call_failed', { message: 'Caller disconnected.' });
    }
  });

  // 8. Direct Calling: Decline Call
  socket.on('decline_call', (data) => {
    io.to(data.callerSocketId).emit('call_declined', { message: 'Call was declined.' });
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

    // Remove from online mapping
    for (const userId in onlineUsers) {
      if (onlineUsers[userId] === socket.id) {
        delete onlineUsers[userId];
        break;
      }
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Signaling server running on port ${PORT}`);
});
