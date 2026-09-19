// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SyncQueueEntriesTable extends SyncQueueEntries
    with TableInfo<$SyncQueueEntriesTable, SyncQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentUuidMeta = const VerificationMeta(
    'parentUuid',
  );
  @override
  late final GeneratedColumn<String> parentUuid = GeneratedColumn<String>(
    'parent_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<int> nextAttemptAt = GeneratedColumn<int>(
    'next_attempt_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdElapsedMeta = const VerificationMeta(
    'createdElapsed',
  );
  @override
  late final GeneratedColumn<int> createdElapsed = GeneratedColumn<int>(
    'created_elapsed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bootIdMeta = const VerificationMeta('bootId');
  @override
  late final GeneratedColumn<String> bootId = GeneratedColumn<String>(
    'boot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entity,
    op,
    clientUuid,
    parentUuid,
    payload,
    localPath,
    state,
    attempts,
    nextAttemptAt,
    lastError,
    createdAt,
    createdElapsed,
    bootId,
    serverId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('parent_uuid')) {
      context.handle(
        _parentUuidMeta,
        parentUuid.isAcceptableOrUnknown(data['parent_uuid']!, _parentUuidMeta),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('created_elapsed')) {
      context.handle(
        _createdElapsedMeta,
        createdElapsed.isAcceptableOrUnknown(
          data['created_elapsed']!,
          _createdElapsedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdElapsedMeta);
    }
    if (data.containsKey('boot_id')) {
      context.handle(
        _bootIdMeta,
        bootId.isAcceptableOrUnknown(data['boot_id']!, _bootIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bootIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      parentUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_uuid'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      createdElapsed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_elapsed'],
      )!,
      bootId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}boot_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
    );
  }

  @override
  $SyncQueueEntriesTable createAlias(String alias) {
    return $SyncQueueEntriesTable(attachedDatabase, alias);
  }
}

class SyncQueueEntry extends DataClass implements Insertable<SyncQueueEntry> {
  final int id;
  final String entity;
  final String op;
  final String clientUuid;
  final String? parentUuid;
  final String payload;
  final String? localPath;
  final String state;
  final int attempts;
  final int? nextAttemptAt;
  final String? lastError;
  final int createdAt;
  final int createdElapsed;
  final String bootId;
  final int? serverId;
  const SyncQueueEntry({
    required this.id,
    required this.entity,
    required this.op,
    required this.clientUuid,
    this.parentUuid,
    required this.payload,
    this.localPath,
    required this.state,
    required this.attempts,
    this.nextAttemptAt,
    this.lastError,
    required this.createdAt,
    required this.createdElapsed,
    required this.bootId,
    this.serverId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity'] = Variable<String>(entity);
    map['op'] = Variable<String>(op);
    map['client_uuid'] = Variable<String>(clientUuid);
    if (!nullToAbsent || parentUuid != null) {
      map['parent_uuid'] = Variable<String>(parentUuid);
    }
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['state'] = Variable<String>(state);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<int>(nextAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['created_elapsed'] = Variable<int>(createdElapsed);
    map['boot_id'] = Variable<String>(bootId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    return map;
  }

  SyncQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueEntriesCompanion(
      id: Value(id),
      entity: Value(entity),
      op: Value(op),
      clientUuid: Value(clientUuid),
      parentUuid: parentUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(parentUuid),
      payload: Value(payload),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      state: Value(state),
      attempts: Value(attempts),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      createdElapsed: Value(createdElapsed),
      bootId: Value(bootId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
    );
  }

  factory SyncQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueEntry(
      id: serializer.fromJson<int>(json['id']),
      entity: serializer.fromJson<String>(json['entity']),
      op: serializer.fromJson<String>(json['op']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      parentUuid: serializer.fromJson<String?>(json['parentUuid']),
      payload: serializer.fromJson<String>(json['payload']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      state: serializer.fromJson<String>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<int?>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      createdElapsed: serializer.fromJson<int>(json['createdElapsed']),
      bootId: serializer.fromJson<String>(json['bootId']),
      serverId: serializer.fromJson<int?>(json['serverId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entity': serializer.toJson<String>(entity),
      'op': serializer.toJson<String>(op),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'parentUuid': serializer.toJson<String?>(parentUuid),
      'payload': serializer.toJson<String>(payload),
      'localPath': serializer.toJson<String?>(localPath),
      'state': serializer.toJson<String>(state),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<int?>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<int>(createdAt),
      'createdElapsed': serializer.toJson<int>(createdElapsed),
      'bootId': serializer.toJson<String>(bootId),
      'serverId': serializer.toJson<int?>(serverId),
    };
  }

  SyncQueueEntry copyWith({
    int? id,
    String? entity,
    String? op,
    String? clientUuid,
    Value<String?> parentUuid = const Value.absent(),
    String? payload,
    Value<String?> localPath = const Value.absent(),
    String? state,
    int? attempts,
    Value<int?> nextAttemptAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    int? createdAt,
    int? createdElapsed,
    String? bootId,
    Value<int?> serverId = const Value.absent(),
  }) => SyncQueueEntry(
    id: id ?? this.id,
    entity: entity ?? this.entity,
    op: op ?? this.op,
    clientUuid: clientUuid ?? this.clientUuid,
    parentUuid: parentUuid.present ? parentUuid.value : this.parentUuid,
    payload: payload ?? this.payload,
    localPath: localPath.present ? localPath.value : this.localPath,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    createdElapsed: createdElapsed ?? this.createdElapsed,
    bootId: bootId ?? this.bootId,
    serverId: serverId.present ? serverId.value : this.serverId,
  );
  SyncQueueEntry copyWithCompanion(SyncQueueEntriesCompanion data) {
    return SyncQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      entity: data.entity.present ? data.entity.value : this.entity,
      op: data.op.present ? data.op.value : this.op,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      parentUuid: data.parentUuid.present
          ? data.parentUuid.value
          : this.parentUuid,
      payload: data.payload.present ? data.payload.value : this.payload,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdElapsed: data.createdElapsed.present
          ? data.createdElapsed.value
          : this.createdElapsed,
      bootId: data.bootId.present ? data.bootId.value : this.bootId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntry(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('op: $op, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('parentUuid: $parentUuid, ')
          ..write('payload: $payload, ')
          ..write('localPath: $localPath, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdElapsed: $createdElapsed, ')
          ..write('bootId: $bootId, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entity,
    op,
    clientUuid,
    parentUuid,
    payload,
    localPath,
    state,
    attempts,
    nextAttemptAt,
    lastError,
    createdAt,
    createdElapsed,
    bootId,
    serverId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueEntry &&
          other.id == this.id &&
          other.entity == this.entity &&
          other.op == this.op &&
          other.clientUuid == this.clientUuid &&
          other.parentUuid == this.parentUuid &&
          other.payload == this.payload &&
          other.localPath == this.localPath &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.createdElapsed == this.createdElapsed &&
          other.bootId == this.bootId &&
          other.serverId == this.serverId);
}

class SyncQueueEntriesCompanion extends UpdateCompanion<SyncQueueEntry> {
  final Value<int> id;
  final Value<String> entity;
  final Value<String> op;
  final Value<String> clientUuid;
  final Value<String?> parentUuid;
  final Value<String> payload;
  final Value<String?> localPath;
  final Value<String> state;
  final Value<int> attempts;
  final Value<int?> nextAttemptAt;
  final Value<String?> lastError;
  final Value<int> createdAt;
  final Value<int> createdElapsed;
  final Value<String> bootId;
  final Value<int?> serverId;
  const SyncQueueEntriesCompanion({
    this.id = const Value.absent(),
    this.entity = const Value.absent(),
    this.op = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.parentUuid = const Value.absent(),
    this.payload = const Value.absent(),
    this.localPath = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdElapsed = const Value.absent(),
    this.bootId = const Value.absent(),
    this.serverId = const Value.absent(),
  });
  SyncQueueEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String entity,
    required String op,
    required String clientUuid,
    this.parentUuid = const Value.absent(),
    required String payload,
    this.localPath = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required int createdAt,
    required int createdElapsed,
    required String bootId,
    this.serverId = const Value.absent(),
  }) : entity = Value(entity),
       op = Value(op),
       clientUuid = Value(clientUuid),
       payload = Value(payload),
       createdAt = Value(createdAt),
       createdElapsed = Value(createdElapsed),
       bootId = Value(bootId);
  static Insertable<SyncQueueEntry> custom({
    Expression<int>? id,
    Expression<String>? entity,
    Expression<String>? op,
    Expression<String>? clientUuid,
    Expression<String>? parentUuid,
    Expression<String>? payload,
    Expression<String>? localPath,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<int>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<int>? createdAt,
    Expression<int>? createdElapsed,
    Expression<String>? bootId,
    Expression<int>? serverId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entity != null) 'entity': entity,
      if (op != null) 'op': op,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (parentUuid != null) 'parent_uuid': parentUuid,
      if (payload != null) 'payload': payload,
      if (localPath != null) 'local_path': localPath,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (createdElapsed != null) 'created_elapsed': createdElapsed,
      if (bootId != null) 'boot_id': bootId,
      if (serverId != null) 'server_id': serverId,
    });
  }

  SyncQueueEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? entity,
    Value<String>? op,
    Value<String>? clientUuid,
    Value<String?>? parentUuid,
    Value<String>? payload,
    Value<String?>? localPath,
    Value<String>? state,
    Value<int>? attempts,
    Value<int?>? nextAttemptAt,
    Value<String?>? lastError,
    Value<int>? createdAt,
    Value<int>? createdElapsed,
    Value<String>? bootId,
    Value<int?>? serverId,
  }) {
    return SyncQueueEntriesCompanion(
      id: id ?? this.id,
      entity: entity ?? this.entity,
      op: op ?? this.op,
      clientUuid: clientUuid ?? this.clientUuid,
      parentUuid: parentUuid ?? this.parentUuid,
      payload: payload ?? this.payload,
      localPath: localPath ?? this.localPath,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      createdElapsed: createdElapsed ?? this.createdElapsed,
      bootId: bootId ?? this.bootId,
      serverId: serverId ?? this.serverId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (parentUuid.present) {
      map['parent_uuid'] = Variable<String>(parentUuid.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<int>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (createdElapsed.present) {
      map['created_elapsed'] = Variable<int>(createdElapsed.value);
    }
    if (bootId.present) {
      map['boot_id'] = Variable<String>(bootId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntriesCompanion(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('op: $op, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('parentUuid: $parentUuid, ')
          ..write('payload: $payload, ')
          ..write('localPath: $localPath, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdElapsed: $createdElapsed, ')
          ..write('bootId: $bootId, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }
}

class $LocalCustomersTable extends LocalCustomers
    with TableInfo<$LocalCustomersTable, LocalCustomer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameUnaccentMeta = const VerificationMeta(
    'nameUnaccent',
  );
  @override
  late final GeneratedColumn<String> nameUnaccent = GeneratedColumn<String>(
    'name_unaccent',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerTypeIdMeta = const VerificationMeta(
    'customerTypeId',
  );
  @override
  late final GeneratedColumn<int> customerTypeId = GeneratedColumn<int>(
    'customer_type_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Điểm bán lẻ'),
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<int> channelId = GeneratedColumn<int>(
    'channel_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelNameMeta = const VerificationMeta(
    'channelName',
  );
  @override
  late final GeneratedColumn<String> channelName = GeneratedColumn<String>(
    'channel_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regionIdMeta = const VerificationMeta(
    'regionId',
  );
  @override
  late final GeneratedColumn<int> regionId = GeneratedColumn<int>(
    'region_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _routeMeta = const VerificationMeta('route');
  @override
  late final GeneratedColumn<String> route = GeneratedColumn<String>(
    'route',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Tuyến mặc định'),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _provinceNameMeta = const VerificationMeta(
    'provinceName',
  );
  @override
  late final GeneratedColumn<String> provinceName = GeneratedColumn<String>(
    'province_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wardNameMeta = const VerificationMeta(
    'wardName',
  );
  @override
  late final GeneratedColumn<String> wardName = GeneratedColumn<String>(
    'ward_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactPersonMeta = const VerificationMeta(
    'contactPerson',
  );
  @override
  late final GeneratedColumn<String> contactPerson = GeneratedColumn<String>(
    'contact_person',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactTitleMeta = const VerificationMeta(
    'contactTitle',
  );
  @override
  late final GeneratedColumn<String> contactTitle = GeneratedColumn<String>(
    'contact_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geofenceRadiusMMeta = const VerificationMeta(
    'geofenceRadiusM',
  );
  @override
  late final GeneratedColumn<int> geofenceRadiusM = GeneratedColumn<int>(
    'geofence_radius_m',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _approvalStatusMeta = const VerificationMeta(
    'approvalStatus',
  );
  @override
  late final GeneratedColumn<String> approvalStatus = GeneratedColumn<String>(
    'approval_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _dynamicFieldsJsonMeta = const VerificationMeta(
    'dynamicFieldsJson',
  );
  @override
  late final GeneratedColumn<String> dynamicFieldsJson =
      GeneratedColumn<String>(
        'dynamic_fields_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientUuid,
    code,
    name,
    nameUnaccent,
    customerTypeId,
    type,
    channelId,
    channelName,
    regionId,
    route,
    address,
    provinceName,
    wardName,
    contactPerson,
    contactTitle,
    phone,
    email,
    lat,
    lng,
    geofenceRadiusM,
    status,
    approvalStatus,
    dynamicFieldsJson,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCustomer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_unaccent')) {
      context.handle(
        _nameUnaccentMeta,
        nameUnaccent.isAcceptableOrUnknown(
          data['name_unaccent']!,
          _nameUnaccentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nameUnaccentMeta);
    }
    if (data.containsKey('customer_type_id')) {
      context.handle(
        _customerTypeIdMeta,
        customerTypeId.isAcceptableOrUnknown(
          data['customer_type_id']!,
          _customerTypeIdMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    }
    if (data.containsKey('channel_name')) {
      context.handle(
        _channelNameMeta,
        channelName.isAcceptableOrUnknown(
          data['channel_name']!,
          _channelNameMeta,
        ),
      );
    }
    if (data.containsKey('region_id')) {
      context.handle(
        _regionIdMeta,
        regionId.isAcceptableOrUnknown(data['region_id']!, _regionIdMeta),
      );
    }
    if (data.containsKey('route')) {
      context.handle(
        _routeMeta,
        route.isAcceptableOrUnknown(data['route']!, _routeMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('province_name')) {
      context.handle(
        _provinceNameMeta,
        provinceName.isAcceptableOrUnknown(
          data['province_name']!,
          _provinceNameMeta,
        ),
      );
    }
    if (data.containsKey('ward_name')) {
      context.handle(
        _wardNameMeta,
        wardName.isAcceptableOrUnknown(data['ward_name']!, _wardNameMeta),
      );
    }
    if (data.containsKey('contact_person')) {
      context.handle(
        _contactPersonMeta,
        contactPerson.isAcceptableOrUnknown(
          data['contact_person']!,
          _contactPersonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contactPersonMeta);
    }
    if (data.containsKey('contact_title')) {
      context.handle(
        _contactTitleMeta,
        contactTitle.isAcceptableOrUnknown(
          data['contact_title']!,
          _contactTitleMeta,
        ),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    }
    if (data.containsKey('geofence_radius_m')) {
      context.handle(
        _geofenceRadiusMMeta,
        geofenceRadiusM.isAcceptableOrUnknown(
          data['geofence_radius_m']!,
          _geofenceRadiusMMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('approval_status')) {
      context.handle(
        _approvalStatusMeta,
        approvalStatus.isAcceptableOrUnknown(
          data['approval_status']!,
          _approvalStatusMeta,
        ),
      );
    }
    if (data.containsKey('dynamic_fields_json')) {
      context.handle(
        _dynamicFieldsJsonMeta,
        dynamicFieldsJson.isAcceptableOrUnknown(
          data['dynamic_fields_json']!,
          _dynamicFieldsJsonMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientUuid};
  @override
  LocalCustomer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCustomer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      ),
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameUnaccent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_unaccent'],
      )!,
      customerTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}customer_type_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channel_id'],
      ),
      channelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_name'],
      ),
      regionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}region_id'],
      ),
      route: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      provinceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}province_name'],
      ),
      wardName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ward_name'],
      ),
      contactPerson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_person'],
      )!,
      contactTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_title'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      ),
      geofenceRadiusM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}geofence_radius_m'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      approvalStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approval_status'],
      )!,
      dynamicFieldsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dynamic_fields_json'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $LocalCustomersTable createAlias(String alias) {
    return $LocalCustomersTable(attachedDatabase, alias);
  }
}

class LocalCustomer extends DataClass implements Insertable<LocalCustomer> {
  final int? id;
  final String clientUuid;
  final String code;
  final String name;
  final String nameUnaccent;
  final int? customerTypeId;
  final String type;
  final int? channelId;
  final String? channelName;
  final int? regionId;
  final String route;
  final String address;
  final String? provinceName;
  final String? wardName;
  final String contactPerson;
  final String? contactTitle;
  final String phone;
  final String? email;
  final double? lat;
  final double? lng;
  final int? geofenceRadiusM;
  final String status;
  final String approvalStatus;
  final String dynamicFieldsJson;
  final String syncStatus;
  final String? createdAt;
  final String? updatedAt;
  const LocalCustomer({
    this.id,
    required this.clientUuid,
    required this.code,
    required this.name,
    required this.nameUnaccent,
    this.customerTypeId,
    required this.type,
    this.channelId,
    this.channelName,
    this.regionId,
    required this.route,
    required this.address,
    this.provinceName,
    this.wardName,
    required this.contactPerson,
    this.contactTitle,
    required this.phone,
    this.email,
    this.lat,
    this.lng,
    this.geofenceRadiusM,
    required this.status,
    required this.approvalStatus,
    required this.dynamicFieldsJson,
    required this.syncStatus,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<int>(id);
    }
    map['client_uuid'] = Variable<String>(clientUuid);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['name_unaccent'] = Variable<String>(nameUnaccent);
    if (!nullToAbsent || customerTypeId != null) {
      map['customer_type_id'] = Variable<int>(customerTypeId);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || channelId != null) {
      map['channel_id'] = Variable<int>(channelId);
    }
    if (!nullToAbsent || channelName != null) {
      map['channel_name'] = Variable<String>(channelName);
    }
    if (!nullToAbsent || regionId != null) {
      map['region_id'] = Variable<int>(regionId);
    }
    map['route'] = Variable<String>(route);
    map['address'] = Variable<String>(address);
    if (!nullToAbsent || provinceName != null) {
      map['province_name'] = Variable<String>(provinceName);
    }
    if (!nullToAbsent || wardName != null) {
      map['ward_name'] = Variable<String>(wardName);
    }
    map['contact_person'] = Variable<String>(contactPerson);
    if (!nullToAbsent || contactTitle != null) {
      map['contact_title'] = Variable<String>(contactTitle);
    }
    map['phone'] = Variable<String>(phone);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    if (!nullToAbsent || geofenceRadiusM != null) {
      map['geofence_radius_m'] = Variable<int>(geofenceRadiusM);
    }
    map['status'] = Variable<String>(status);
    map['approval_status'] = Variable<String>(approvalStatus);
    map['dynamic_fields_json'] = Variable<String>(dynamicFieldsJson);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  LocalCustomersCompanion toCompanion(bool nullToAbsent) {
    return LocalCustomersCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      clientUuid: Value(clientUuid),
      code: Value(code),
      name: Value(name),
      nameUnaccent: Value(nameUnaccent),
      customerTypeId: customerTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerTypeId),
      type: Value(type),
      channelId: channelId == null && nullToAbsent
          ? const Value.absent()
          : Value(channelId),
      channelName: channelName == null && nullToAbsent
          ? const Value.absent()
          : Value(channelName),
      regionId: regionId == null && nullToAbsent
          ? const Value.absent()
          : Value(regionId),
      route: Value(route),
      address: Value(address),
      provinceName: provinceName == null && nullToAbsent
          ? const Value.absent()
          : Value(provinceName),
      wardName: wardName == null && nullToAbsent
          ? const Value.absent()
          : Value(wardName),
      contactPerson: Value(contactPerson),
      contactTitle: contactTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(contactTitle),
      phone: Value(phone),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      geofenceRadiusM: geofenceRadiusM == null && nullToAbsent
          ? const Value.absent()
          : Value(geofenceRadiusM),
      status: Value(status),
      approvalStatus: Value(approvalStatus),
      dynamicFieldsJson: Value(dynamicFieldsJson),
      syncStatus: Value(syncStatus),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory LocalCustomer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCustomer(
      id: serializer.fromJson<int?>(json['id']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      nameUnaccent: serializer.fromJson<String>(json['nameUnaccent']),
      customerTypeId: serializer.fromJson<int?>(json['customerTypeId']),
      type: serializer.fromJson<String>(json['type']),
      channelId: serializer.fromJson<int?>(json['channelId']),
      channelName: serializer.fromJson<String?>(json['channelName']),
      regionId: serializer.fromJson<int?>(json['regionId']),
      route: serializer.fromJson<String>(json['route']),
      address: serializer.fromJson<String>(json['address']),
      provinceName: serializer.fromJson<String?>(json['provinceName']),
      wardName: serializer.fromJson<String?>(json['wardName']),
      contactPerson: serializer.fromJson<String>(json['contactPerson']),
      contactTitle: serializer.fromJson<String?>(json['contactTitle']),
      phone: serializer.fromJson<String>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      geofenceRadiusM: serializer.fromJson<int?>(json['geofenceRadiusM']),
      status: serializer.fromJson<String>(json['status']),
      approvalStatus: serializer.fromJson<String>(json['approvalStatus']),
      dynamicFieldsJson: serializer.fromJson<String>(json['dynamicFieldsJson']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int?>(id),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'nameUnaccent': serializer.toJson<String>(nameUnaccent),
      'customerTypeId': serializer.toJson<int?>(customerTypeId),
      'type': serializer.toJson<String>(type),
      'channelId': serializer.toJson<int?>(channelId),
      'channelName': serializer.toJson<String?>(channelName),
      'regionId': serializer.toJson<int?>(regionId),
      'route': serializer.toJson<String>(route),
      'address': serializer.toJson<String>(address),
      'provinceName': serializer.toJson<String?>(provinceName),
      'wardName': serializer.toJson<String?>(wardName),
      'contactPerson': serializer.toJson<String>(contactPerson),
      'contactTitle': serializer.toJson<String?>(contactTitle),
      'phone': serializer.toJson<String>(phone),
      'email': serializer.toJson<String?>(email),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'geofenceRadiusM': serializer.toJson<int?>(geofenceRadiusM),
      'status': serializer.toJson<String>(status),
      'approvalStatus': serializer.toJson<String>(approvalStatus),
      'dynamicFieldsJson': serializer.toJson<String>(dynamicFieldsJson),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  LocalCustomer copyWith({
    Value<int?> id = const Value.absent(),
    String? clientUuid,
    String? code,
    String? name,
    String? nameUnaccent,
    Value<int?> customerTypeId = const Value.absent(),
    String? type,
    Value<int?> channelId = const Value.absent(),
    Value<String?> channelName = const Value.absent(),
    Value<int?> regionId = const Value.absent(),
    String? route,
    String? address,
    Value<String?> provinceName = const Value.absent(),
    Value<String?> wardName = const Value.absent(),
    String? contactPerson,
    Value<String?> contactTitle = const Value.absent(),
    String? phone,
    Value<String?> email = const Value.absent(),
    Value<double?> lat = const Value.absent(),
    Value<double?> lng = const Value.absent(),
    Value<int?> geofenceRadiusM = const Value.absent(),
    String? status,
    String? approvalStatus,
    String? dynamicFieldsJson,
    String? syncStatus,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => LocalCustomer(
    id: id.present ? id.value : this.id,
    clientUuid: clientUuid ?? this.clientUuid,
    code: code ?? this.code,
    name: name ?? this.name,
    nameUnaccent: nameUnaccent ?? this.nameUnaccent,
    customerTypeId: customerTypeId.present
        ? customerTypeId.value
        : this.customerTypeId,
    type: type ?? this.type,
    channelId: channelId.present ? channelId.value : this.channelId,
    channelName: channelName.present ? channelName.value : this.channelName,
    regionId: regionId.present ? regionId.value : this.regionId,
    route: route ?? this.route,
    address: address ?? this.address,
    provinceName: provinceName.present ? provinceName.value : this.provinceName,
    wardName: wardName.present ? wardName.value : this.wardName,
    contactPerson: contactPerson ?? this.contactPerson,
    contactTitle: contactTitle.present ? contactTitle.value : this.contactTitle,
    phone: phone ?? this.phone,
    email: email.present ? email.value : this.email,
    lat: lat.present ? lat.value : this.lat,
    lng: lng.present ? lng.value : this.lng,
    geofenceRadiusM: geofenceRadiusM.present
        ? geofenceRadiusM.value
        : this.geofenceRadiusM,
    status: status ?? this.status,
    approvalStatus: approvalStatus ?? this.approvalStatus,
    dynamicFieldsJson: dynamicFieldsJson ?? this.dynamicFieldsJson,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  LocalCustomer copyWithCompanion(LocalCustomersCompanion data) {
    return LocalCustomer(
      id: data.id.present ? data.id.value : this.id,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      nameUnaccent: data.nameUnaccent.present
          ? data.nameUnaccent.value
          : this.nameUnaccent,
      customerTypeId: data.customerTypeId.present
          ? data.customerTypeId.value
          : this.customerTypeId,
      type: data.type.present ? data.type.value : this.type,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      channelName: data.channelName.present
          ? data.channelName.value
          : this.channelName,
      regionId: data.regionId.present ? data.regionId.value : this.regionId,
      route: data.route.present ? data.route.value : this.route,
      address: data.address.present ? data.address.value : this.address,
      provinceName: data.provinceName.present
          ? data.provinceName.value
          : this.provinceName,
      wardName: data.wardName.present ? data.wardName.value : this.wardName,
      contactPerson: data.contactPerson.present
          ? data.contactPerson.value
          : this.contactPerson,
      contactTitle: data.contactTitle.present
          ? data.contactTitle.value
          : this.contactTitle,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      geofenceRadiusM: data.geofenceRadiusM.present
          ? data.geofenceRadiusM.value
          : this.geofenceRadiusM,
      status: data.status.present ? data.status.value : this.status,
      approvalStatus: data.approvalStatus.present
          ? data.approvalStatus.value
          : this.approvalStatus,
      dynamicFieldsJson: data.dynamicFieldsJson.present
          ? data.dynamicFieldsJson.value
          : this.dynamicFieldsJson,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCustomer(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('nameUnaccent: $nameUnaccent, ')
          ..write('customerTypeId: $customerTypeId, ')
          ..write('type: $type, ')
          ..write('channelId: $channelId, ')
          ..write('channelName: $channelName, ')
          ..write('regionId: $regionId, ')
          ..write('route: $route, ')
          ..write('address: $address, ')
          ..write('provinceName: $provinceName, ')
          ..write('wardName: $wardName, ')
          ..write('contactPerson: $contactPerson, ')
          ..write('contactTitle: $contactTitle, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('geofenceRadiusM: $geofenceRadiusM, ')
          ..write('status: $status, ')
          ..write('approvalStatus: $approvalStatus, ')
          ..write('dynamicFieldsJson: $dynamicFieldsJson, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    clientUuid,
    code,
    name,
    nameUnaccent,
    customerTypeId,
    type,
    channelId,
    channelName,
    regionId,
    route,
    address,
    provinceName,
    wardName,
    contactPerson,
    contactTitle,
    phone,
    email,
    lat,
    lng,
    geofenceRadiusM,
    status,
    approvalStatus,
    dynamicFieldsJson,
    syncStatus,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCustomer &&
          other.id == this.id &&
          other.clientUuid == this.clientUuid &&
          other.code == this.code &&
          other.name == this.name &&
          other.nameUnaccent == this.nameUnaccent &&
          other.customerTypeId == this.customerTypeId &&
          other.type == this.type &&
          other.channelId == this.channelId &&
          other.channelName == this.channelName &&
          other.regionId == this.regionId &&
          other.route == this.route &&
          other.address == this.address &&
          other.provinceName == this.provinceName &&
          other.wardName == this.wardName &&
          other.contactPerson == this.contactPerson &&
          other.contactTitle == this.contactTitle &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.geofenceRadiusM == this.geofenceRadiusM &&
          other.status == this.status &&
          other.approvalStatus == this.approvalStatus &&
          other.dynamicFieldsJson == this.dynamicFieldsJson &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalCustomersCompanion extends UpdateCompanion<LocalCustomer> {
  final Value<int?> id;
  final Value<String> clientUuid;
  final Value<String> code;
  final Value<String> name;
  final Value<String> nameUnaccent;
  final Value<int?> customerTypeId;
  final Value<String> type;
  final Value<int?> channelId;
  final Value<String?> channelName;
  final Value<int?> regionId;
  final Value<String> route;
  final Value<String> address;
  final Value<String?> provinceName;
  final Value<String?> wardName;
  final Value<String> contactPerson;
  final Value<String?> contactTitle;
  final Value<String> phone;
  final Value<String?> email;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<int?> geofenceRadiusM;
  final Value<String> status;
  final Value<String> approvalStatus;
  final Value<String> dynamicFieldsJson;
  final Value<String> syncStatus;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const LocalCustomersCompanion({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.nameUnaccent = const Value.absent(),
    this.customerTypeId = const Value.absent(),
    this.type = const Value.absent(),
    this.channelId = const Value.absent(),
    this.channelName = const Value.absent(),
    this.regionId = const Value.absent(),
    this.route = const Value.absent(),
    this.address = const Value.absent(),
    this.provinceName = const Value.absent(),
    this.wardName = const Value.absent(),
    this.contactPerson = const Value.absent(),
    this.contactTitle = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.geofenceRadiusM = const Value.absent(),
    this.status = const Value.absent(),
    this.approvalStatus = const Value.absent(),
    this.dynamicFieldsJson = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCustomersCompanion.insert({
    this.id = const Value.absent(),
    required String clientUuid,
    this.code = const Value.absent(),
    required String name,
    required String nameUnaccent,
    this.customerTypeId = const Value.absent(),
    this.type = const Value.absent(),
    this.channelId = const Value.absent(),
    this.channelName = const Value.absent(),
    this.regionId = const Value.absent(),
    this.route = const Value.absent(),
    required String address,
    this.provinceName = const Value.absent(),
    this.wardName = const Value.absent(),
    required String contactPerson,
    this.contactTitle = const Value.absent(),
    required String phone,
    this.email = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.geofenceRadiusM = const Value.absent(),
    this.status = const Value.absent(),
    this.approvalStatus = const Value.absent(),
    this.dynamicFieldsJson = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : clientUuid = Value(clientUuid),
       name = Value(name),
       nameUnaccent = Value(nameUnaccent),
       address = Value(address),
       contactPerson = Value(contactPerson),
       phone = Value(phone);
  static Insertable<LocalCustomer> custom({
    Expression<int>? id,
    Expression<String>? clientUuid,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? nameUnaccent,
    Expression<int>? customerTypeId,
    Expression<String>? type,
    Expression<int>? channelId,
    Expression<String>? channelName,
    Expression<int>? regionId,
    Expression<String>? route,
    Expression<String>? address,
    Expression<String>? provinceName,
    Expression<String>? wardName,
    Expression<String>? contactPerson,
    Expression<String>? contactTitle,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<int>? geofenceRadiusM,
    Expression<String>? status,
    Expression<String>? approvalStatus,
    Expression<String>? dynamicFieldsJson,
    Expression<String>? syncStatus,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (nameUnaccent != null) 'name_unaccent': nameUnaccent,
      if (customerTypeId != null) 'customer_type_id': customerTypeId,
      if (type != null) 'type': type,
      if (channelId != null) 'channel_id': channelId,
      if (channelName != null) 'channel_name': channelName,
      if (regionId != null) 'region_id': regionId,
      if (route != null) 'route': route,
      if (address != null) 'address': address,
      if (provinceName != null) 'province_name': provinceName,
      if (wardName != null) 'ward_name': wardName,
      if (contactPerson != null) 'contact_person': contactPerson,
      if (contactTitle != null) 'contact_title': contactTitle,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (geofenceRadiusM != null) 'geofence_radius_m': geofenceRadiusM,
      if (status != null) 'status': status,
      if (approvalStatus != null) 'approval_status': approvalStatus,
      if (dynamicFieldsJson != null) 'dynamic_fields_json': dynamicFieldsJson,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCustomersCompanion copyWith({
    Value<int?>? id,
    Value<String>? clientUuid,
    Value<String>? code,
    Value<String>? name,
    Value<String>? nameUnaccent,
    Value<int?>? customerTypeId,
    Value<String>? type,
    Value<int?>? channelId,
    Value<String?>? channelName,
    Value<int?>? regionId,
    Value<String>? route,
    Value<String>? address,
    Value<String?>? provinceName,
    Value<String?>? wardName,
    Value<String>? contactPerson,
    Value<String?>? contactTitle,
    Value<String>? phone,
    Value<String?>? email,
    Value<double?>? lat,
    Value<double?>? lng,
    Value<int?>? geofenceRadiusM,
    Value<String>? status,
    Value<String>? approvalStatus,
    Value<String>? dynamicFieldsJson,
    Value<String>? syncStatus,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalCustomersCompanion(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      code: code ?? this.code,
      name: name ?? this.name,
      nameUnaccent: nameUnaccent ?? this.nameUnaccent,
      customerTypeId: customerTypeId ?? this.customerTypeId,
      type: type ?? this.type,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      regionId: regionId ?? this.regionId,
      route: route ?? this.route,
      address: address ?? this.address,
      provinceName: provinceName ?? this.provinceName,
      wardName: wardName ?? this.wardName,
      contactPerson: contactPerson ?? this.contactPerson,
      contactTitle: contactTitle ?? this.contactTitle,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      geofenceRadiusM: geofenceRadiusM ?? this.geofenceRadiusM,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      dynamicFieldsJson: dynamicFieldsJson ?? this.dynamicFieldsJson,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameUnaccent.present) {
      map['name_unaccent'] = Variable<String>(nameUnaccent.value);
    }
    if (customerTypeId.present) {
      map['customer_type_id'] = Variable<int>(customerTypeId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<int>(channelId.value);
    }
    if (channelName.present) {
      map['channel_name'] = Variable<String>(channelName.value);
    }
    if (regionId.present) {
      map['region_id'] = Variable<int>(regionId.value);
    }
    if (route.present) {
      map['route'] = Variable<String>(route.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (provinceName.present) {
      map['province_name'] = Variable<String>(provinceName.value);
    }
    if (wardName.present) {
      map['ward_name'] = Variable<String>(wardName.value);
    }
    if (contactPerson.present) {
      map['contact_person'] = Variable<String>(contactPerson.value);
    }
    if (contactTitle.present) {
      map['contact_title'] = Variable<String>(contactTitle.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (geofenceRadiusM.present) {
      map['geofence_radius_m'] = Variable<int>(geofenceRadiusM.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (approvalStatus.present) {
      map['approval_status'] = Variable<String>(approvalStatus.value);
    }
    if (dynamicFieldsJson.present) {
      map['dynamic_fields_json'] = Variable<String>(dynamicFieldsJson.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCustomersCompanion(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('nameUnaccent: $nameUnaccent, ')
          ..write('customerTypeId: $customerTypeId, ')
          ..write('type: $type, ')
          ..write('channelId: $channelId, ')
          ..write('channelName: $channelName, ')
          ..write('regionId: $regionId, ')
          ..write('route: $route, ')
          ..write('address: $address, ')
          ..write('provinceName: $provinceName, ')
          ..write('wardName: $wardName, ')
          ..write('contactPerson: $contactPerson, ')
          ..write('contactTitle: $contactTitle, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('geofenceRadiusM: $geofenceRadiusM, ')
          ..write('status: $status, ')
          ..write('approvalStatus: $approvalStatus, ')
          ..write('dynamicFieldsJson: $dynamicFieldsJson, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SyncQueueEntriesTable syncQueueEntries = $SyncQueueEntriesTable(
    this,
  );
  late final $LocalCustomersTable localCustomers = $LocalCustomersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncQueueEntries,
    localCustomers,
  ];
}

typedef $$SyncQueueEntriesTableCreateCompanionBuilder =
    SyncQueueEntriesCompanion Function({
      Value<int> id,
      required String entity,
      required String op,
      required String clientUuid,
      Value<String?> parentUuid,
      required String payload,
      Value<String?> localPath,
      Value<String> state,
      Value<int> attempts,
      Value<int?> nextAttemptAt,
      Value<String?> lastError,
      required int createdAt,
      required int createdElapsed,
      required String bootId,
      Value<int?> serverId,
    });
typedef $$SyncQueueEntriesTableUpdateCompanionBuilder =
    SyncQueueEntriesCompanion Function({
      Value<int> id,
      Value<String> entity,
      Value<String> op,
      Value<String> clientUuid,
      Value<String?> parentUuid,
      Value<String> payload,
      Value<String?> localPath,
      Value<String> state,
      Value<int> attempts,
      Value<int?> nextAttemptAt,
      Value<String?> lastError,
      Value<int> createdAt,
      Value<int> createdElapsed,
      Value<String> bootId,
      Value<int?> serverId,
    });

class $$SyncQueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueEntriesTable> {
  $$SyncQueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentUuid => $composableBuilder(
    column: $table.parentUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdElapsed => $composableBuilder(
    column: $table.createdElapsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bootId => $composableBuilder(
    column: $table.bootId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueEntriesTable> {
  $$SyncQueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentUuid => $composableBuilder(
    column: $table.parentUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdElapsed => $composableBuilder(
    column: $table.createdElapsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bootId => $composableBuilder(
    column: $table.bootId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueEntriesTable> {
  $$SyncQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentUuid => $composableBuilder(
    column: $table.parentUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get createdElapsed => $composableBuilder(
    column: $table.createdElapsed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bootId =>
      $composableBuilder(column: $table.bootId, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);
}

class $$SyncQueueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueEntriesTable,
          SyncQueueEntry,
          $$SyncQueueEntriesTableFilterComposer,
          $$SyncQueueEntriesTableOrderingComposer,
          $$SyncQueueEntriesTableAnnotationComposer,
          $$SyncQueueEntriesTableCreateCompanionBuilder,
          $$SyncQueueEntriesTableUpdateCompanionBuilder,
          (
            SyncQueueEntry,
            BaseReferences<
              _$AppDatabase,
              $SyncQueueEntriesTable,
              SyncQueueEntry
            >,
          ),
          SyncQueueEntry,
          PrefetchHooks Function()
        > {
  $$SyncQueueEntriesTableTableManager(
    _$AppDatabase db,
    $SyncQueueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String?> parentUuid = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int?> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> createdElapsed = const Value.absent(),
                Value<String> bootId = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
              }) => SyncQueueEntriesCompanion(
                id: id,
                entity: entity,
                op: op,
                clientUuid: clientUuid,
                parentUuid: parentUuid,
                payload: payload,
                localPath: localPath,
                state: state,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                createdElapsed: createdElapsed,
                bootId: bootId,
                serverId: serverId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entity,
                required String op,
                required String clientUuid,
                Value<String?> parentUuid = const Value.absent(),
                required String payload,
                Value<String?> localPath = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int?> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required int createdAt,
                required int createdElapsed,
                required String bootId,
                Value<int?> serverId = const Value.absent(),
              }) => SyncQueueEntriesCompanion.insert(
                id: id,
                entity: entity,
                op: op,
                clientUuid: clientUuid,
                parentUuid: parentUuid,
                payload: payload,
                localPath: localPath,
                state: state,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                createdElapsed: createdElapsed,
                bootId: bootId,
                serverId: serverId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncQueueEntriesTable, SyncQueueEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncQueueEntriesTable,
                    SyncQueueEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueEntriesTable,
      SyncQueueEntry,
      $$SyncQueueEntriesTableFilterComposer,
      $$SyncQueueEntriesTableOrderingComposer,
      $$SyncQueueEntriesTableAnnotationComposer,
      $$SyncQueueEntriesTableCreateCompanionBuilder,
      $$SyncQueueEntriesTableUpdateCompanionBuilder,
      (
        SyncQueueEntry,
        BaseReferences<_$AppDatabase, $SyncQueueEntriesTable, SyncQueueEntry>,
      ),
      SyncQueueEntry,
      PrefetchHooks Function()
    >;
typedef $$LocalCustomersTableCreateCompanionBuilder =
    LocalCustomersCompanion Function({
      Value<int?> id,
      required String clientUuid,
      Value<String> code,
      required String name,
      required String nameUnaccent,
      Value<int?> customerTypeId,
      Value<String> type,
      Value<int?> channelId,
      Value<String?> channelName,
      Value<int?> regionId,
      Value<String> route,
      required String address,
      Value<String?> provinceName,
      Value<String?> wardName,
      required String contactPerson,
      Value<String?> contactTitle,
      required String phone,
      Value<String?> email,
      Value<double?> lat,
      Value<double?> lng,
      Value<int?> geofenceRadiusM,
      Value<String> status,
      Value<String> approvalStatus,
      Value<String> dynamicFieldsJson,
      Value<String> syncStatus,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<int> rowid,
    });
typedef $$LocalCustomersTableUpdateCompanionBuilder =
    LocalCustomersCompanion Function({
      Value<int?> id,
      Value<String> clientUuid,
      Value<String> code,
      Value<String> name,
      Value<String> nameUnaccent,
      Value<int?> customerTypeId,
      Value<String> type,
      Value<int?> channelId,
      Value<String?> channelName,
      Value<int?> regionId,
      Value<String> route,
      Value<String> address,
      Value<String?> provinceName,
      Value<String?> wardName,
      Value<String> contactPerson,
      Value<String?> contactTitle,
      Value<String> phone,
      Value<String?> email,
      Value<double?> lat,
      Value<double?> lng,
      Value<int?> geofenceRadiusM,
      Value<String> status,
      Value<String> approvalStatus,
      Value<String> dynamicFieldsJson,
      Value<String> syncStatus,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<int> rowid,
    });

class $$LocalCustomersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCustomersTable> {
  $$LocalCustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameUnaccent => $composableBuilder(
    column: $table.nameUnaccent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customerTypeId => $composableBuilder(
    column: $table.customerTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get regionId => $composableBuilder(
    column: $table.regionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provinceName => $composableBuilder(
    column: $table.provinceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wardName => $composableBuilder(
    column: $table.wardName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactPerson => $composableBuilder(
    column: $table.contactPerson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactTitle => $composableBuilder(
    column: $table.contactTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get geofenceRadiusM => $composableBuilder(
    column: $table.geofenceRadiusM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvalStatus => $composableBuilder(
    column: $table.approvalStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dynamicFieldsJson => $composableBuilder(
    column: $table.dynamicFieldsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCustomersTable> {
  $$LocalCustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameUnaccent => $composableBuilder(
    column: $table.nameUnaccent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customerTypeId => $composableBuilder(
    column: $table.customerTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get regionId => $composableBuilder(
    column: $table.regionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provinceName => $composableBuilder(
    column: $table.provinceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wardName => $composableBuilder(
    column: $table.wardName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactPerson => $composableBuilder(
    column: $table.contactPerson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactTitle => $composableBuilder(
    column: $table.contactTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get geofenceRadiusM => $composableBuilder(
    column: $table.geofenceRadiusM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvalStatus => $composableBuilder(
    column: $table.approvalStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dynamicFieldsJson => $composableBuilder(
    column: $table.dynamicFieldsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCustomersTable> {
  $$LocalCustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameUnaccent => $composableBuilder(
    column: $table.nameUnaccent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get customerTypeId => $composableBuilder(
    column: $table.customerTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get regionId =>
      $composableBuilder(column: $table.regionId, builder: (column) => column);

  GeneratedColumn<String> get route =>
      $composableBuilder(column: $table.route, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get provinceName => $composableBuilder(
    column: $table.provinceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get wardName =>
      $composableBuilder(column: $table.wardName, builder: (column) => column);

  GeneratedColumn<String> get contactPerson => $composableBuilder(
    column: $table.contactPerson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactTitle => $composableBuilder(
    column: $table.contactTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<int> get geofenceRadiusM => $composableBuilder(
    column: $table.geofenceRadiusM,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get approvalStatus => $composableBuilder(
    column: $table.approvalStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dynamicFieldsJson => $composableBuilder(
    column: $table.dynamicFieldsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalCustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalCustomersTable,
          LocalCustomer,
          $$LocalCustomersTableFilterComposer,
          $$LocalCustomersTableOrderingComposer,
          $$LocalCustomersTableAnnotationComposer,
          $$LocalCustomersTableCreateCompanionBuilder,
          $$LocalCustomersTableUpdateCompanionBuilder,
          (
            LocalCustomer,
            BaseReferences<_$AppDatabase, $LocalCustomersTable, LocalCustomer>,
          ),
          LocalCustomer,
          PrefetchHooks Function()
        > {
  $$LocalCustomersTableTableManager(
    _$AppDatabase db,
    $LocalCustomersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int?> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameUnaccent = const Value.absent(),
                Value<int?> customerTypeId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> channelId = const Value.absent(),
                Value<String?> channelName = const Value.absent(),
                Value<int?> regionId = const Value.absent(),
                Value<String> route = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String?> provinceName = const Value.absent(),
                Value<String?> wardName = const Value.absent(),
                Value<String> contactPerson = const Value.absent(),
                Value<String?> contactTitle = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<int?> geofenceRadiusM = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> approvalStatus = const Value.absent(),
                Value<String> dynamicFieldsJson = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCustomersCompanion(
                id: id,
                clientUuid: clientUuid,
                code: code,
                name: name,
                nameUnaccent: nameUnaccent,
                customerTypeId: customerTypeId,
                type: type,
                channelId: channelId,
                channelName: channelName,
                regionId: regionId,
                route: route,
                address: address,
                provinceName: provinceName,
                wardName: wardName,
                contactPerson: contactPerson,
                contactTitle: contactTitle,
                phone: phone,
                email: email,
                lat: lat,
                lng: lng,
                geofenceRadiusM: geofenceRadiusM,
                status: status,
                approvalStatus: approvalStatus,
                dynamicFieldsJson: dynamicFieldsJson,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int?> id = const Value.absent(),
                required String clientUuid,
                Value<String> code = const Value.absent(),
                required String name,
                required String nameUnaccent,
                Value<int?> customerTypeId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> channelId = const Value.absent(),
                Value<String?> channelName = const Value.absent(),
                Value<int?> regionId = const Value.absent(),
                Value<String> route = const Value.absent(),
                required String address,
                Value<String?> provinceName = const Value.absent(),
                Value<String?> wardName = const Value.absent(),
                required String contactPerson,
                Value<String?> contactTitle = const Value.absent(),
                required String phone,
                Value<String?> email = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<int?> geofenceRadiusM = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> approvalStatus = const Value.absent(),
                Value<String> dynamicFieldsJson = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCustomersCompanion.insert(
                id: id,
                clientUuid: clientUuid,
                code: code,
                name: name,
                nameUnaccent: nameUnaccent,
                customerTypeId: customerTypeId,
                type: type,
                channelId: channelId,
                channelName: channelName,
                regionId: regionId,
                route: route,
                address: address,
                provinceName: provinceName,
                wardName: wardName,
                contactPerson: contactPerson,
                contactTitle: contactTitle,
                phone: phone,
                email: email,
                lat: lat,
                lng: lng,
                geofenceRadiusM: geofenceRadiusM,
                status: status,
                approvalStatus: approvalStatus,
                dynamicFieldsJson: dynamicFieldsJson,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalCustomersTable, LocalCustomer>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalCustomersTable,
                    LocalCustomer
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalCustomersTable,
      LocalCustomer,
      $$LocalCustomersTableFilterComposer,
      $$LocalCustomersTableOrderingComposer,
      $$LocalCustomersTableAnnotationComposer,
      $$LocalCustomersTableCreateCompanionBuilder,
      $$LocalCustomersTableUpdateCompanionBuilder,
      (
        LocalCustomer,
        BaseReferences<_$AppDatabase, $LocalCustomersTable, LocalCustomer>,
      ),
      LocalCustomer,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SyncQueueEntriesTableTableManager get syncQueueEntries =>
      $$SyncQueueEntriesTableTableManager(_db, _db.syncQueueEntries);
  $$LocalCustomersTableTableManager get localCustomers =>
      $$LocalCustomersTableTableManager(_db, _db.localCustomers);
}
