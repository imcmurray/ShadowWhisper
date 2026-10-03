// UI element coordinates for 1280x720 viewport
// These coordinates are derived from existing test files

module.exports = {
  landing: {
    createRoomButton: { x: 640, y: 655 },
    joinRoomButton: { x: 640, y: 702 },
  },

  createRoom: {
    roomNameInput: { x: 640, y: 393 },
    approvalToggle: { x: 640, y: 490 },
    createButton: { x: 640, y: 563 },
    copyCodeButton: { x: 640, y: 485 },
    enterRoomButton: { x: 640, y: 578 },
  },

  joinRoom: {
    roomCodeInput: { x: 640, y: 397 },
    joinButton: { x: 640, y: 471 },
  },

  chat: {
    messageInput: { x: 640, y: 650 },
    sendButton: { x: 1247, y: 650 },
    participantsButton: { x: 1178, y: 28 },
    settingsButton: { x: 1218, y: 28 },
    leaveButton: { x: 1258, y: 28 },
    endRoomButton: { x: 1138, y: 28 },
    // First message bubble (received, left-aligned) - approximate center
    firstMessageBubble: { x: 200, y: 150 },
    // Own message bubble (sent, right-aligned) - approximate center
    ownMessageBubble: { x: 1000, y: 150 },
  },

  // Reaction picker modal (bottom sheet)
  reactionPicker: {
    // Emoji positions in the picker (evenly spaced)
    thumbsUp: { x: 320, y: 620 },
    heart: { x: 440, y: 620 },
    laughing: { x: 560, y: 620 },
    surprised: { x: 680, y: 620 },
    crying: { x: 800, y: 620 },
    thumbsDown: { x: 920, y: 620 },
  },

  participantDrawer: {
    closeButton: { x: 900, y: 100 },
    firstParticipantKickButton: { x: 1200, y: 180 },
    approveButton: { x: 1150, y: 180 },
    rejectButton: { x: 1200, y: 180 },
  },

  waitingRoom: {
    backButton: { x: 100, y: 50 },
  },

  // Typing indicator location (above message input)
  typingIndicator: { x: 640, y: 610 },
};
