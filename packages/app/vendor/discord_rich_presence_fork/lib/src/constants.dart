enum DiscordCommands {
  dispatch('DISPATCH'),
  authorized('AUTHORIZE'),
  authenticate('AUTHENTICATE'),
  setActivity('SET_ACTIVITY');

  const DiscordCommands(this.name);
  final String name;
}
