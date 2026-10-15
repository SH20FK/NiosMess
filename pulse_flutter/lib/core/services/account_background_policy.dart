/// One decision for sockets, the foreground service and its CPU wake lock.
class AccountBackgroundPolicy {
  const AccountBackgroundPolicy({
    required bool authenticated,
    required bool background,
    required bool reliable,
    required bool activeWork,
  }) : keepSocket = authenticated && (!background || reliable || activeWork),
       keepService = authenticated && (reliable || activeWork),
       keepCpuAwake = authenticated && activeWork;

  final bool keepSocket;
  final bool keepService;
  final bool keepCpuAwake;
}
