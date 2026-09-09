import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';

typedef WorkspaceRef = ({Workspace workspace, UserRole role});

/// Workspace (şirket / çalışma alanı), üyelik ve e-posta davetleri.
///
/// Firestore yapısı:
/// ```
/// workspaces/{wid}                 -> { name, ownerUid, status, createdAt }
/// workspaces/{wid}/members/{uid}   -> { uid, role, email, name, addedAt, addedBy }
/// workspace_invites/{wid_email}    -> { workspaceId, workspaceName, email, role,
///                                       invitedBy, status, createdAt }
/// users/{uid}.defaultWorkspaceId   -> {wid}
/// ```
class WorkspaceRepository {
  WorkspaceRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _workspaces =>
      _db.collection('workspaces');
  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('workspace_invites');
  CollectionReference<Map<String, dynamic>> _members(String wid) =>
      _workspaces.doc(wid).collection('members');

  String _inviteId(String wid, String email) => '${wid}_${email.toLowerCase()}';

  // ─── Workspace oluşturma ──────────────────────────────────────────────────

  /// Yeni kayıt olan kullanıcı için bir workspace oluşturur ve kullanıcıyı
  /// o workspace'in `admin` (sahip) üyesi yapar.
  Future<String> createWorkspaceForUser({
    required String uid,
    required String name,
    String? email,
    String? displayName,
  }) async {
    final wsRef = _workspaces.doc();

    // Önce workspace dokümanı: member create kuralı get(workspace).ownerUid'e
    // baktığından bu yazının önce commit edilmesi gerekir.
    await wsRef.set({
      'name': name.trim().isEmpty ? 'Çalışma Alanı' : name.trim(),
      'ownerUid': uid,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final batch = _db.batch();
    batch.set(_members(wsRef.id).doc(uid), {
      'uid': uid,
      'role': UserRole.admin.name,
      'email': email,
      'name': displayName,
      'addedAt': FieldValue.serverTimestamp(),
      'addedBy': uid,
    });
    batch.set(_db.collection('users').doc(uid), {
      'defaultWorkspaceId': wsRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();

    return wsRef.id;
  }

  Stream<Workspace?> watch(String wid) => _workspaces
      .doc(wid)
      .snapshots()
      .map((d) => d.exists ? Workspace.fromDoc(d) : null);

  Future<Workspace?> getById(String wid) async {
    final d = await _workspaces.doc(wid).get();
    return d.exists ? Workspace.fromDoc(d) : null;
  }

  Future<void> updateName({
    required String wid,
    required String name,
  }) =>
      _workspaces.doc(wid).set({
        'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  // ─── Üyeler ───────────────────────────────────────────────────────────────

  Stream<List<WorkspaceMembership>> members(String wid) => _members(wid)
      .snapshots()
      .map((s) => s.docs.map(WorkspaceMembership.fromDoc).toList());

  Stream<WorkspaceMembership?> myMembership(String wid, String uid) =>
      _members(wid).doc(uid).snapshots().map(
          (d) => d.exists ? WorkspaceMembership.fromDoc(d) : null);

  Future<void> setMemberRole({
    required String wid,
    required String uid,
    required UserRole role,
    required String actorUid,
  }) =>
      _members(wid).doc(uid).set({
        'uid': uid,
        'role': role.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actorUid,
      }, SetOptions(merge: true));

  Future<void> removeMember(String wid, String uid) =>
      _members(wid).doc(uid).delete();

  // ─── Kullanıcının workspace'leri / geçiş ──────────────────────────────────

  Future<List<WorkspaceRef>> myWorkspaces(String uid) async {
    final memberSnaps = await _db
        .collectionGroup('members')
        .where('uid', isEqualTo: uid)
        .get();

    final out = <WorkspaceRef>[];
    for (final m in memberSnaps.docs) {
      final wid = m.reference.parent.parent?.id;
      if (wid == null) continue;
      final wsDoc = await _workspaces.doc(wid).get();
      if (!wsDoc.exists) continue;
      out.add((
        workspace: Workspace.fromDoc(wsDoc),
        role: UserRoleLabel.fromString(m.data()['role'] ?? 'viewer'),
      ));
    }
    out.sort((a, b) => a.workspace.name.compareTo(b.workspace.name));
    return out;
  }

  Future<void> setDefaultWorkspace(String uid, String wid) =>
      _db.collection('users').doc(uid).set({
        'defaultWorkspaceId': wid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  // ─── Davetler ─────────────────────────────────────────────────────────────

  Future<void> createInvite({
    required String workspaceId,
    required String workspaceName,
    required String email,
    required UserRole role,
    required String invitedBy,
  }) {
    final e = email.trim().toLowerCase();
    return _invites.doc(_inviteId(workspaceId, e)).set({
      'workspaceId': workspaceId,
      'workspaceName': workspaceName,
      'email': e,
      'role': role.name,
      'invitedBy': invitedBy,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<WorkspaceInvite>> workspaceInvites(String wid) => _invites
      .where('workspaceId', isEqualTo: wid)
      .snapshots()
      .map((s) => s.docs.map(WorkspaceInvite.fromDoc).toList());

  /// E-posta adresine gelen bekleyen davetler.
  Stream<List<WorkspaceInvite>> invitesForEmail(String email) => _invites
      .where('email', isEqualTo: email.toLowerCase())
      .snapshots()
      .map((s) => s.docs
          .map(WorkspaceInvite.fromDoc)
          .where((i) => i.isPending)
          .toList());

  Future<void> revokeInvite(String inviteId) => _invites.doc(inviteId).delete();

  /// Daveti kabul et: üyelik oluştur, daveti "accepted" yap, kullanıcının
  /// varsayılan workspace'i yoksa bunu ata.
  Future<void> acceptInvite({
    required WorkspaceInvite invite,
    required String uid,
    String? email,
    String? displayName,
  }) async {
    // 1) Üyelik — davet 'pending' iken oluşturulmalı (kural bunu kontrol eder).
    await _members(invite.workspaceId).doc(uid).set({
      'uid': uid,
      'role': invite.role.name,
      'email': email,
      'name': displayName,
      'addedAt': FieldValue.serverTimestamp(),
      'addedBy': invite.invitedBy,
    });

    // 2) Daveti kapat.
    await _invites.doc(invite.id).set({
      'status': 'accepted',
      'acceptedBy': uid,
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3) Varsayılan workspace yoksa ata.
    final u = await _db.collection('users').doc(uid).get();
    final current = (u.data()?['defaultWorkspaceId'] ?? '').toString();
    if (current.isEmpty) {
      await setDefaultWorkspace(uid, invite.workspaceId);
    }
  }

  Future<void> declineInvite(WorkspaceInvite invite) =>
      _invites.doc(invite.id).set({
        'status': 'declined',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
