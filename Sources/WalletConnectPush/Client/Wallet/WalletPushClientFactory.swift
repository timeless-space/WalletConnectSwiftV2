import Foundation

public struct WalletPushClientFactory {

    public static func create(networkInteractor: NetworkInteracting, pairingRegisterer: PairingRegisterer, echoClient: EchoClient, syncClient: SyncClient) -> WalletPushClient {
        let logger = ConsoleLogger(suffix: "🔔",loggingLevel: .debug)
        let keyValueStorage = UserDefaults.standard
        let keyserverURL = URL(string: "https://keys.walletconnect.com")!
        let keychainStorage = KeychainStorage(serviceIdentifier: "com.walletconnect.sdk")
        let groupKeychainService = GroupKeychainStorage(serviceIdentifier: "group.com.walletconnect.sdk")

        return WalletPushClientFactory.create(
            keyserverURL: keyserverURL,
            logger: logger,
            keyValueStorage: keyValueStorage,
            keychainStorage: keychainStorage,
            groupKeychainStorage: groupKeychainService,
            networkInteractor: networkInteractor,
            pairingRegisterer: pairingRegisterer,
            echoClient: echoClient,
            syncClient: syncClient
        )
    }

    static func create(
        keyserverURL: URL,
        logger: ConsoleLogging,
        keyValueStorage: KeyValueStorage,
        keychainStorage: KeychainStorageProtocol,
        groupKeychainStorage: KeychainStorageProtocol,
        networkInteractor: NetworkInteracting,
        pairingRegisterer: PairingRegisterer,
        echoClient: EchoClient,
        syncClient: SyncClient
    ) -> WalletPushClient {
        let kms = KeyManagementService(keychain: keychainStorage)
        let history = RPCHistoryFactory.createForNetwork(keyValueStorage: keyValueStorage)
        let subscriptionStore: SyncStore<PushSubscription> = SyncStoreFactory.create(name: PushStorageIdntifiers.pushSubscription, syncClient: syncClient, storage: keyValueStorage)
        let subscriptionStoreDelegate = PushSubscriptionStoreDelegate(networkingInteractor: networkInteractor, kms: kms)
        let pushStorage = PushStorage(subscriptionStore: subscriptionStore, subscriptionStoreDelegate: subscriptionStoreDelegate)
        let identityClient = IdentityClientFactory.create(keyserver: keyserverURL, keychain: keychainStorage, logger: logger)
        let pushMessagesRecordsStore = CodableStore<PushMessageRecord>(defaults: keyValueStorage, identifier: PushStorageIdntifiers.pushMessagesRecords)
        let pushMessagesDatabase = PushMessagesDatabase(store: pushMessagesRecordsStore)
        let pushMessageSubscriber = PushMessageSubscriber(networkingInteractor: networkInteractor, pushMessagesDatabase: pushMessagesDatabase, logger: logger)
        let deletePushSubscriptionService = DeletePushSubscriptionService(networkingInteractor: networkInteractor, kms: kms, logger: logger, pushStorage: pushStorage, pushMessagesDatabase: pushMessagesDatabase)
        let resubscribeService = PushResubscribeService(networkInteractor: networkInteractor, pushStorage: pushStorage)

        let dappsMetadataStore = CodableStore<AppMetadata>(defaults: keyValueStorage, identifier: PushStorageIdntifiers.dappsMetadataStore)
        let subscriptionScopeProvider = SubscriptionScopeProvider()

        let pushSubscribeRequester = PushSubscribeRequester(keyserverURL: keyserverURL, networkingInteractor: networkInteractor, identityClient: identityClient, logger: logger, kms: kms, subscriptionScopeProvider: subscriptionScopeProvider, dappsMetadataStore: dappsMetadataStore)

        let pushSubscribeResponseSubscriber = PushSubscribeResponseSubscriber(networkingInteractor: networkInteractor, kms: kms, logger: logger, groupKeychainStorage: groupKeychainStorage, pushStorage: pushStorage, dappsMetadataStore: dappsMetadataStore, subscriptionScopeProvider: subscriptionScopeProvider)

        let notifyUpdateRequester = NotifyUpdateRequester(keyserverURL: keyserverURL, identityClient: identityClient, networkingInteractor: networkInteractor, logger: logger, pushStorage: pushStorage)

        let notifyUpdateResponseSubscriber = NotifyUpdateResponseSubscriber(networkingInteractor: networkInteractor, logger: logger, subscriptionScopeProvider: subscriptionScopeProvider, pushStorage: pushStorage)
        let notifyProposeResponder = NotifyProposeResponder(networkingInteractor: networkInteractor, kms: kms, logger: logger, pushStorage: pushStorage, pushSubscribeRequester: pushSubscribeRequester, rpcHistory: history, pushSubscribeResponseSubscriber: pushSubscribeResponseSubscriber)

        let notifyProposeSubscriber = NotifyProposeSubscriber(networkingInteractor: networkInteractor, pushStorage: pushStorage, logger: logger, pairingRegisterer: pairingRegisterer)

        let deletePushSubscriptionSubscriber = DeletePushSubscriptionSubscriber(networkingInteractor: networkInteractor, kms: kms, logger: logger, pushStorage: pushStorage)

        return WalletPushClient(
            logger: logger,
            kms: kms,
            echoClient: echoClient,
            syncClient: syncClient,
            pushMessageSubscriber: pushMessageSubscriber,
            pushStorage: pushStorage,
            pushMessagesDatabase: pushMessagesDatabase,
            deletePushSubscriptionService: deletePushSubscriptionService,
            resubscribeService: resubscribeService,
            pushSubscribeRequester: pushSubscribeRequester,
            pushSubscribeResponseSubscriber: pushSubscribeResponseSubscriber,
            deletePushSubscriptionSubscriber: deletePushSubscriptionSubscriber,
            notifyUpdateRequester: notifyUpdateRequester,
            notifyUpdateResponseSubscriber: notifyUpdateResponseSubscriber,
            notifyProposeResponder: notifyProposeResponder,
            notifyProposeSubscriber: notifyProposeSubscriber
        )
    }
}
