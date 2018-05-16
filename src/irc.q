/////////////
// PRIVATE //
/////////////

.irc.priv.nick:`kdbBot
.irc.priv.real:"q/kdb+ IRC Bot"

.irc.priv.callbacks:2!flip`command`callback`repeat!"ssb"$\:()

.irc.priv.topics:()!()
.irc.priv.nickList:()!()

.irc.priv.chanServ:1b
.irc.priv.joinOnInvite:1b
.irc.priv.rejoinOnKick:1b

.irc.priv.disconnectCallback:{[message]
  .log.warning("Disconnected from IRC, attempting reconnect in 10 seconds");
  .irc.priv.unregisterCallbacksByCommand[`001];
  .timer.in[`irc.reconnect;0D00:00:10;`.irc.connect;`.irc.priv `server`nick`callback`channels];
  }

.irc.priv.connectCallback:{[args]
  .log.info"Connected to IRC";

  .irc.identify .(.irc.priv`nick`password),`.irc.priv.identifyCallback;
  }

.irc.priv.identifyCallback:{[args]
  .log.info("Identified as";.irc.priv.nick);
  if[.irc.priv.chanServ;
    .irc.privmsg["ChanServ"]'["INVITE ",/:string(),.irc.priv.channels]];
  @[0;(.irc.priv.callback;[]);::];
  }

.irc.priv.messageCallback:{[message]
  .log.debug message;
  prefix:$[":"=first message;1_ first" "vs message;""];
  username:first"!"vs prefix;
  command:`$first$[":"=first first command:" "vs message;1_ command;command];
  arguments:2_" "vs first" :"vs message;
  message:" :"sv 1_" :"vs message;

  callbacks:?[`.irc.priv.callbacks;enlist(=;`command;enlist command);0b;(!/)2#enlist`callback`repeat];
  {[args;callback]
    @[0;(callback`callback;args);{[callback;x]
        .log.error("Callback failed:";callback);
        .log.error x;
        }[callback]];
    if[not callback`repeat;
      .irc.priv.unregisterCallback . callback`command`callback];
    }[`prefix`username`command`arguments`message!(prefix;username;command;arguments;message)]'[callbacks];
  }

.irc.priv.send:{[data]
  .irc.priv.ircsend[.log.priv.stringify[data],"\r\n"]}

.irc.priv.pong:{[args]
  .irc.priv.send[("PONG";args`message)];
  }

.irc.priv.topic:{[args]
  .irc.priv.topics[`$last args`arguments]:args`message;
  }

.irc.priv.names:{[args]
  nicks:`$@[message;;1_]where any"~&@%+"=\:first@'message:" "vs trim args`message;
  .irc.priv.nickList[channel:`$last args`arguments],:nicks;
  }

.irc.priv.nickListDelete:{[channel;nick]
  .irc.priv.nickList[channel]_:.irc.priv.nickList[channel]?nick;
  }

.irc.priv.part:{[args]
  nick:`$args`username;
  channel:`$last args`arguments;
  $[.irc.priv.nick~nick;
    ![.irc.priv.nickList;();0b;enlist channel];
    .irc.priv.nickListDelete[channel;nick]];
  }

.irc.priv.quit:{[args]
  nick:`$args`username;
  $[.irc.priv.nick~nick;
    .irc.priv.nickList:()!();
    .irc.priv.nickListDelete[;nick]'[.irc.priv.channels]];
  }

.irc.priv.kick:{[args]
  nick:`$args[`arguments;1];
  channel:`$args[`arguments;0];
  $[.irc.priv.nick~nick;
    [
      // Clear nickList
      ![`.irc.priv.nickList;();0b;enlist channel];
      // Rejoin channel
      if[.irc.priv.rejoinOnKick;
        .timer.in[` sv`rejoin,channel;0D00:00:01;`.irc.join;channel]]];
    .irc.priv.nickListDelete[channel;nick]];
  }

.irc.priv.join:{[args]
  nick:`$args`username;
  channel:`$args`message;
  if[not .irc.priv.nick~nick;
    // Update nickList
    .irc.priv.nickList[channel],:nick];
  }

.irc.priv.invite:{[args]
  channel:`$args`message;
  if[.irc.priv.joinOnInvite&channel in .irc.priv.channels;
    // Join channel
    .timer.in[` sv`invite,channel;0D00:00:01;`.irc.join;channel]];
  }

.irc.priv.registerCallback:{[command;callback;repeat;overwrite]
  if[overwrite;
    .irc.priv.unregisterCallbacksByCommand[command]];
  .log.debug("Registering callback for";command;callback);
  upsert[`.irc.priv.callbacks;(command;callback;repeat)];
  }

.irc.priv.unregisterCallback:{[command;callback]
  .log.debug("Unregistering callback for";command;callback);
  ![`.irc.priv.callbacks;
    ((=;`command;enlist command);(=;`callback;enlist callback));0b;`symbol$()];
  }

.irc.priv.unregisterCallbacksByCommand:{[command]
  .log.debug("Unregistering callbacks for";command);
  ![`.irc.priv.callbacks;enlist(=;`command;enlist command);0b;`symbol$()];
  }

.irc.priv.registerCallback[`332;`.irc.priv.topic;1b;1b]
.irc.priv.registerCallback[`353;`.irc.priv.names;1b;1b]
.irc.priv.registerCallback[`INVITE;`.irc.priv.invite;1b;1b]
.irc.priv.registerCallback[`JOIN;`.irc.priv.join;1b;1b]
.irc.priv.registerCallback[`KICK;`.irc.priv.kick;1b;1b]
.irc.priv.registerCallback[`PART;`.irc.priv.part;1b;1b]
.irc.priv.registerCallback[`PING;`.irc.priv.pong;1b;1b]
.irc.priv.registerCallback[`QUIT;`.irc.priv.quit;1b;1b]

/////////
// API //
/////////

.irc.api.isOnChannel:{[channel;nick]
  nick in .irc.priv.nickList[channel]}

.irc.api.isOnAnyChannel:{[nick]
  any .irc.api.isOnChannel[;nick]'[.irc.priv.channels]}

////////////
// PUBLIC //
////////////

///
// Connect to IRC server
// @param server symbol IRC server
// @param nick symbol Nickname
// @param callback symbol Callback function
.irc.connect:{[server;nick;password;callback;channels]
  `.irc.priv.server set server;
  `.irc.priv.nick set nick;
  `.irc.priv.password set password;
  `.irc.priv.callback set callback;
  `.irc.priv.channels set channels;

  id:.irc.priv.registerCallback[`001;`.irc.priv.connectCallback;0b;1b];
  if[not .irc.priv.ircconnect[server];
    .irc.priv.unregisterCallbacksByCommand[`001];
    :0b];
  if[not .irc.nick[nick];
    .irc.priv.unregisterCallbacksByCommand[`001];
    :0b];
  if[not .irc.user[nick;.irc.priv.real];
    .irc.priv.unregisterCallbacksByCommand[`001];
    :0b];
  1b}

///
// Disconnect from IRC server
.irc.disconnect:{[]
  .irc.priv.ircdisconnect[]}

///
// Sets IRC nickname as specified
// @param nick symbol Nickname
.irc.nick:{[nick]
  .irc.priv.send[("NICK";nick)]}

///
// Registers the new user at startup
// @param nick symbol Nickname
// @param real string Real name
.irc.user:{[nick;real]
  .irc.priv.send[("USER";nick;"0 * :",real)]}

///
// Quits IRC with a specified message
// @param message string Quit message
.irc.quit:{[message]
  .irc.priv.send[("QUIT";":",message)]}

///
// Joins the specified IRC channel
// @param channel symbol Channel name
.irc.join:{[channel]
  .irc.priv.send[("JOIN";channel)]}

///
// Parts the specified IRC channel
// @param channel symbol Channel name
.irc.part:{[channel]
  .irc.priv.send[("PART";channel)]}

///
// Sets channel or nickname mode
// @param dest symbol Channel/Nickname
// @param mode string Mode
.irc.mode:{[dest;mode]
  .irc.priv.send[("MODE";dest;mode)]}

///
// Sets the channel topic
// @param channel symbol Channel
// @param topic string Topic
.irc.topic:{[channel;topic]
  .irc.priv.send[("TOPIC";channel;":",topic)]}

///
// Invites the given user into a channel
// @param nick symbol Nickname
// @param channel symbol Channel
.irc.invite:{[nick;channel]
  .irc.priv.send[("INVITE";nick;channel)]}

///
// Kicks the given user from a channel
// @param channel symbol Channel
// @param user symbol User
// @param comment string Comment
.irc.kick:{[channel;user;comment]
  .irc.priv.send[("KICK";channel;user;":",comment)]}

///
// Sends a private message to a channel or user
// @param dest symbol/symbolList List of recipients
// @param message string Message
.irc.privmsg:{[dest;message]
  if[11=type dest;
    dest:","sv string dest];
  .irc.priv.send[("PRIVMSG";dest;":",message)]}

///
// Sends a notice to a channel or user
// @param dest symbol/symbolList List of recipients
// @param message string Message
.irc.notice:{[dest;message]
  if[11=type dest;
    dest:","sv string dest];
  .irc.priv.send[("NOTICE";dest;":",message)]}

.irc.identify:{[user;password;callback]
  .irc.priv.registerCallback[`900;callback;0b;1b];
  .irc.priv.send[("PRIVMSG";"NickServ";"IDENTIFY";user;password)];
  }

//////////
// INIT //
//////////

{[func;argCount]
  (` sv`.irc.priv,func)set(` sv(.utl.PKGSLOADED"irc"),`lib,` sv`irc,.z.o)2:(func;argCount);
  }[;1]'[`ircconnect`ircdisconnect`ircsend];
