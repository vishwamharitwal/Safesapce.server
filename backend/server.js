require('dotenv').config(); // ← .env file se environment variables load karo
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

// ─── Supabase JWT Secret ───
// Set this in your .env file or deployment environment:
//   SUPABASE_JWT_SECRET=your_jwt_secret_from_supabase_dashboard
// Supabase Dashboard → Settings → API → JWT Secret
const SUPABASE_JWT_SECRET = process.env.SUPABASE_JWT_SECRET || '';

// Initialize server with enhanced logging
console.log('----------------------------------------------------');
console.log('🚀 SYSTEM DEEP SCAN: Signaling Server Booting...');
console.log(`🔑 SUPABASE_JWT_SECRET Status: ${SUPABASE_JWT_SECRET ? 'SET (Length: ' + SUPABASE_JWT_SECRET.length + ')' : 'NOT SET! ❌'}`);
console.log('----------------------------------------------------');


const app = express();
app.use(cors());
app.use(express.json());

// ─── Global State & Tracking ───
// These must be defined before they are used in route handlers!
const waitingQueues = {};
const activeRooms = {};
const userSessions = {};
const socketUserMap = {};

// 🏠 ROOT route for checking server status via browser
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    message: 'SafeSpace Signaling Server is LIVE 🚀 (v1.0.1)',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    activeRooms: Object.keys(activeRooms).length,
    connectedUsers: Object.keys(userSessions).length,
    transports: 'websocket,polling'
  });
});

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
    credentials: true
  },
  pingTimeout: 60000,
  pingInterval: 25000,
  // 🚀 Allow both polling and websocket for initial handshake compatibility
  transports: ['polling', 'websocket']
});


// 🛡️ Global Socket.io Error Handler
io.on('connection_error', (err) => {
  console.log('❌ Connection Error:', err.type, err.message, err.context);
});

// ─── 🛡️ JWT Auth Middleware ───
// Runs BEFORE every socket connection is established.
// Rejects any socket that doesn't carry a valid Supabase JWT.
io.use((socket, next) => {
  // If secret not configured, skip verification (dev fallback)
  if (!SUPABASE_JWT_SECRET) {
    console.warn(`[Auth] JWT secret missing — skipping auth for ${socket.id}`);
    return next();
  }

  const token = socket.handshake.auth?.token;

  if (!token) {
    console.warn(`[Auth] ❌ Connection rejected — no token provided (${socket.handshake.address})`);
    return next(new Error('Unauthorized: No token provided'));
  }

  try {
    // 🕵️ Debug: Check what algorithm is being sent
    const decodedHeader = jwt.decode(token, { complete: true })?.header;
    console.log(`[Auth] 🕵️ Token incoming algorithm: ${decodedHeader?.alg || 'NOT_FOUND'}`);

    // Verify the Supabase JWT (Supports HS256 and ECC)
    const decoded = jwt.verify(token, SUPABASE_JWT_SECRET);

    // Attach verified userId to socket for use in all event handlers
    socket.verifiedUserId = decoded.sub; // 'sub' = Supabase user UUID
    socket.verifiedEmail   = decoded.email || null;

    console.log(`[Auth] ✅ Auth OK — userId: ${decoded.sub?.substring(0, 8)}...`);
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      console.warn(`[Auth] ⏰ Token expired for ${socket.handshake.address}`);
      return next(new Error('Unauthorized: Token expired'));
    }
    console.warn(`[Auth] ❌ Invalid token: ${err.message}`);
    return next(new Error('Unauthorized: Invalid token'));
  }
});

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
  const transport = socket.conn.transport.name;
  console.log(`📡 [New Conn] ${socket.id} | Transport: ${transport} | Handshake: ${JSON.stringify(socket.handshake.query)}`);
  console.log(`📡 Connection established: ${socket.id} | userId: ${socket.verifiedUserId?.substring(0,8) ?? 'unverified'}...`);

  socket.on('register_user', (data) => {
    if (!data || !data.userId) return;

    // 🛡️ Security: Use the server-verified userId, NOT what client sends
    // This prevents spoofing (client can't pretend to be another user)
    const userId = socket.verifiedUserId || data.userId;

    // If JWT is set, reject if client userId doesn't match JWT sub
    if (SUPABASE_JWT_SECRET && socket.verifiedUserId && socket.verifiedUserId !== data.userId) {
      console.warn(`[Security] ⚠️  UserId mismatch! JWT: ${socket.verifiedUserId}, Client sent: ${data.userId} — using JWT value`);
    }

    // Save mapping for disconnect tracking
    socketUserMap[socket.id] = userId;
    
    // Clear deletion timeout if user reconnected
    if (userSessions[userId] && userSessions[userId].deleteTimeout) {
      clearTimeout(userSessions[userId].deleteTimeout);
      delete userSessions[userId].deleteTimeout;
    }

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

      // CRITICAL: Update the stale socketId in the room data so events reach the right socket
      const room = activeRooms[roomId];
      if (room.talker.userId === userId) {
        console.log(`🔄 Updating talker socketId in room ${roomId}: ${room.talker.socketId} -> ${socket.id}`);
        room.talker.socketId = socket.id;
      }
      if (room.listener.userId === userId) {
        console.log(`🔄 Updating listener socketId in room ${roomId}: ${room.listener.socketId} -> ${socket.id}`);
        room.listener.socketId = socket.id;
      }

      console.log(`🔄 User ${userId} auto-rejoined room ${roomId}`);

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
        console.log(`📡 [resync] Room ${roomId} already accepted. Sending partner_connected to ${socket.id} in 500ms`);
        setTimeout(() => {
          io.to(socket.id).emit('partner_connected', {
            partnerId: partner.userId,
            partnerName: partner.nickname || 'Someone',
            partnerAvatar: partner.avatar || ''
          });
        }, 500);
      }
    }
  });

  socket.on('find_match', (data) => {
    if (!data || !data.topic || !data.role) return;

    // 🛡️ Always use server-verified userId from JWT
    const userId = socket.verifiedUserId || data.userId;
    if (!userId) {
      console.warn('[Security] find_match rejected — no verified userId');
      return;
    }

    const { role, topic, nickname, avatar, rating, targetTime } = data;
    
    // Save mapping for disconnect tracking
    socketUserMap[socket.id] = userId;

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
    let partnerIndex = -1;

    const targetQueue = role === 'talk' ? queue.listeners : queue.talkers;
    for (let i = 0; i < targetQueue.length; i++) {
      const entry = targetQueue[i];
      if (!io.sockets.sockets.has(entry.socketId)) {
        targetQueue.splice(i, 1);
        i--;
        continue;
      }
      
      if (entry.targetTime === targetTime) {
        partnerEntry = entry;
        partnerIndex = i;
        break;
      }
    }

    if (partnerEntry) {
      targetQueue.splice(partnerIndex, 1);
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
      const entry = { socketId: socket.id, userId, nickname, avatar, rating, targetTime };
      if (role === 'talk') queue.talkers.push(entry);
      else queue.listeners.push(entry);

      socket.emit('waiting_for_match');
      console.log(`⏳ ${nickname || 'User'} waiting in ${topic}`);
    }
  });

  socket.on('accept_match', (data) => {
    if (!data || !data.roomId) return;
    const { roomId } = data;
    console.log(`[accept_match] Received for room: ${roomId} from socket ${socket.id}`);
    if (activeRooms[roomId]) {
      activeRooms[roomId].isAccepted = true;
      const room = activeRooms[roomId];

      // CRITICAL FIX: Use CURRENT socket IDs from userSessions, NOT stale ones from activeRooms
      // When a user reconnects, their socketId changes but activeRooms still has the old one
      const listenerUserId = room.listener.userId;
      const talkerUserId = room.talker.userId;

      let currentListenerSocketId = userSessions[listenerUserId]?.socketId || room.listener.socketId;
      let currentTalkerSocketId = userSessions[talkerUserId]?.socketId || room.talker.socketId;

      // Handle edge case: testing on the SAME user account in two tabs
      if (listenerUserId === talkerUserId && currentListenerSocketId === currentTalkerSocketId) {
        currentListenerSocketId = room.listener.socketId;
        currentTalkerSocketId = room.talker.socketId;
      }

      console.log(`[accept_match] Listener: stored=${room.listener.socketId}, current=${currentListenerSocketId}`);
      console.log(`[accept_match] Talker: stored=${room.talker.socketId}, current=${currentTalkerSocketId}`);

      // Also update the room's socketIds so future events use the right ones
      room.listener.socketId = currentListenerSocketId;
      room.talker.socketId = currentTalkerSocketId;

      // Re-join both sockets to the room (in case they reconnected)
      const listenerSocket = io.sockets.sockets.get(currentListenerSocketId);
      const talkerSocket = io.sockets.sockets.get(currentTalkerSocketId);
      if (listenerSocket) listenerSocket.join(roomId);
      if (talkerSocket) talkerSocket.join(roomId);

      // Emit to CURRENT socket IDs with payload in case match_found was missed!
      io.to(currentListenerSocketId).emit('partner_connected', {
        partnerId: talkerUserId,
        partnerName: room.talker.nickname,
        partnerAvatar: room.talker.avatar
      });
      io.to(currentTalkerSocketId).emit('partner_connected', {
        partnerId: listenerUserId,
        partnerName: room.listener.nickname,
        partnerAvatar: room.listener.avatar
      });
      // Also broadcast to room as fallback
      socket.to(roomId).emit('partner_connected', {});

      console.log(`👍 Match accepted in ${roomId}. Listener socket exists: ${!!listenerSocket}, Talker socket exists: ${!!talkerSocket}`);
    } else {
      console.log(`[accept_match] Room ${roomId} NOT FOUND in active rooms! Cannot accept.`);
    }
  });

  socket.on('skip_match', (data) => {
    if (!data || !data.roomId) return;
    const { roomId } = data;
    if (activeRooms[roomId]) {
      socket.to(roomId).emit('match_skipped');
      const room = activeRooms[roomId];
      if (userSessions[room.talker.userId]) userSessions[room.talker.userId].currentRoomId = null;
      if (userSessions[room.listener.userId]) userSessions[room.listener.userId].currentRoomId = null;
      delete activeRooms[roomId];
    }
  });

  // Signaling Relays (🛡️ Secure Relay)
  socket.on('webrtc_offer', (data) => {
    if (!data || !data.roomId) return;
    
    // Security: Verify user is who they say they are in JWT
    if (socket.verifiedUserId && socket.verifiedUserId !== socketUserMap[socket.id]) {
      console.warn(`🛑 [Security] Blocked unauthorized webrtc_offer from ${socket.id}`);
      return;
    }

    if (socket.rooms.has(data.roomId)) socket.to(data.roomId).emit('webrtc_offer', data);
  });
  
  socket.on('webrtc_answer', (data) => {
    if (!data || !data.roomId) return;
    
    if (socket.verifiedUserId && socket.verifiedUserId !== socketUserMap[socket.id]) {
      console.warn(`🛑 [Security] Blocked unauthorized webrtc_answer from ${socket.id}`);
      return;
    }

    if (socket.rooms.has(data.roomId)) socket.to(data.roomId).emit('webrtc_answer', data);
  });
  
  socket.on('webrtc_ice_candidate', (data) => {
    if (!data || !data.roomId) return;
    
    if (socket.verifiedUserId && socket.verifiedUserId !== socketUserMap[socket.id]) {
      console.warn(`🛑 [Security] Blocked unauthorized webrtc_ice_candidate from ${socket.id}`);
      return;
    }

    if (socket.rooms.has(data.roomId)) socket.to(data.roomId).emit('webrtc_ice_candidate', data);
  });

  socket.on('end_session', (data) => {
    if (!data || !data.roomId) return;
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

    // Get userId to perform cleanup
    const userId = socketUserMap[socket.id];
    delete socketUserMap[socket.id];

    // Optimize disconnect: find room quickly via user session
    if (userId && userSessions[userId]) {
      const roomId = userSessions[userId].currentRoomId;
      if (roomId && activeRooms[roomId]) {
        const room = activeRooms[roomId];
        // Ensure this user actually belongs to THIS socket ID right now
        // to prevent false disconnect processing if they just reconnected
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

      // Memory Leak Fix: Set a timeout to clean up session
      userSessions[userId].deleteTimeout = setTimeout(() => {
        console.log(`🧹 Memory Cleanup: Removing inactive session for user ${userId}`);
        delete userSessions[userId];
      }, 5 * 60 * 1000); // 5 minutes TTL
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

// 🚉 Railway Connectivity: Use process.env.PORT or default to 8080 (Railway default)
const PORT = process.env.PORT || 8080;

// Force server to listen on 0.0.0.0 to accept external traffic from Railway proxy
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server started on 0.0.0.0:${PORT}`);
  console.log(`📈 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🌐 Public URL: https://safesapceserver-production.up.railway.app`);
});
