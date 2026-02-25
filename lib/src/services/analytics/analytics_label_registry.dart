import 'package:core/core.dart';

/// {@template analytics_label_registry}
/// A static registry containing hardcoded translations for all analytics cards.
///
/// This acts as the server-side "Source of Truth" for UI labels on the dashboard.
/// While the database stores these labels, this registry ensures they are
/// populated with all supported languages during the sync process.
/// {@endtemplate}
abstract class AnalyticsLabelRegistry {
  /// Retrieves the localized label map for a given KPI card.
  static Map<SupportedLanguage, String> getKpiLabel(KpiCardId id) {
    final labels = <SupportedLanguage, String>{};
    for (final entry in _kpiLabels.entries) {
      if (entry.value.containsKey(id)) {
        labels[entry.key] = entry.value[id]!;
      }
    }
    return labels.isNotEmpty
        ? labels
        : {SupportedLanguage.en: _formatFallback(id.name)};
  }

  /// Retrieves the localized label map for a given Chart card.
  static Map<SupportedLanguage, String> getChartLabel(ChartCardId id) {
    final labels = <SupportedLanguage, String>{};
    for (final entry in _chartLabels.entries) {
      if (entry.value.containsKey(id)) {
        labels[entry.key] = entry.value[id]!;
      }
    }
    return labels.isNotEmpty
        ? labels
        : {SupportedLanguage.en: _formatFallback(id.name)};
  }

  /// Retrieves the localized label map for a given Ranked List card.
  static Map<SupportedLanguage, String> getRankedListLabel(
    RankedListCardId id,
  ) {
    final labels = <SupportedLanguage, String>{};
    for (final entry in _rankedListLabels.entries) {
      if (entry.value.containsKey(id)) {
        labels[entry.key] = entry.value[id]!;
      }
    }
    return labels.isNotEmpty
        ? labels
        : {SupportedLanguage.en: _formatFallback(id.name)};
  }

  // Helper to format enum names if a translation is missing (fallback).
  static String _formatFallback(String idName) {
    var spaced = idName.replaceAllMapped(
      RegExp('([A-Z])'),
      (m) => ' ${m.group(1)}',
    );
    spaced = spaced[0].toUpperCase() + spaced.substring(1);
    return spaced.trim();
  }

  /// A map containing the display labels for each KPI card in all supported languages.
  static final Map<SupportedLanguage, Map<KpiCardId, String>> _kpiLabels = {
    SupportedLanguage.en: {
      KpiCardId.usersTotalRegistered: 'Total Users',
      KpiCardId.usersNewRegistrations: 'New Registrations',
      KpiCardId.usersActiveUsers: 'Active Users',
      KpiCardId.contentHeadlinesTotalPublished: 'Total Headlines',
      KpiCardId.contentHeadlinesTotalViews: 'Total Views',
      KpiCardId.contentHeadlinesTotalLikes: 'Total Likes',
      KpiCardId.contentSourcesTotalSources: 'Total Sources',
      KpiCardId.contentSourcesNewSources: 'New Sources',
      KpiCardId.contentSourcesTotalFollowers: 'Total Followers',
      KpiCardId.contentTopicsTotalTopics: 'Total Topics',
      KpiCardId.contentTopicsNewTopics: 'New Topics',
      KpiCardId.contentTopicsTotalFollowers: 'Total Followers',
      KpiCardId.engagementsTotalReactions: 'Total Reactions',
      KpiCardId.engagementsTotalComments: 'Total Comments',
      KpiCardId.engagementsAverageEngagementRate: 'Avg. Engagement Rate',
      KpiCardId.engagementsReportsPending: 'Pending Reports',
      KpiCardId.engagementsReportsResolved: 'Resolved Reports',
      KpiCardId.engagementsReportsAverageResolutionTime: 'Avg. Resolution Time',
      KpiCardId.engagementsAppReviewsTotalFeedback: 'Total Feedback',
      KpiCardId.engagementsAppReviewsPositiveFeedback: 'Positive Feedback',
      KpiCardId.engagementsAppReviewsStoreRequests: 'Store Requests',
      KpiCardId.rewardsAdsWatchedTotal: 'Ads Watched',
      KpiCardId.rewardsGrantedTotal: 'Rewards Granted',
      KpiCardId.rewardsActiveUsersCount: 'Active Reward Users',
    },
    SupportedLanguage.ar: {
      KpiCardId.usersTotalRegistered: 'إجمالي المستخدمين',
      KpiCardId.usersNewRegistrations: 'التسجيلات الجديدة',
      KpiCardId.usersActiveUsers: 'المستخدمون النشطون',
      KpiCardId.contentHeadlinesTotalPublished: 'إجمالي العناوين',
      KpiCardId.contentHeadlinesTotalViews: 'إجمالي المشاهدات',
      KpiCardId.contentHeadlinesTotalLikes: 'إجمالي الإعجابات',
      KpiCardId.contentSourcesTotalSources: 'إجمالي المصادر',
      KpiCardId.contentSourcesNewSources: 'مصادر جديدة',
      KpiCardId.contentSourcesTotalFollowers: 'إجمالي المتابعين',
      KpiCardId.contentTopicsTotalTopics: 'إجمالي المواضيع',
      KpiCardId.contentTopicsNewTopics: 'مواضيع جديدة',
      KpiCardId.contentTopicsTotalFollowers: 'إجمالي المتابعين',
      KpiCardId.engagementsTotalReactions: 'إجمالي التفاعلات',
      KpiCardId.engagementsTotalComments: 'إجمالي التعليقات',
      KpiCardId.engagementsAverageEngagementRate: 'متوسط معدل التفاعل',
      KpiCardId.engagementsReportsPending: 'تقارير معلقة',
      KpiCardId.engagementsReportsResolved: 'تقارير محلولة',
      KpiCardId.engagementsReportsAverageResolutionTime: 'متوسط وقت الحل',
      KpiCardId.engagementsAppReviewsTotalFeedback: 'إجمالي التقييمات',
      KpiCardId.engagementsAppReviewsPositiveFeedback: 'تقييمات إيجابية',
      KpiCardId.engagementsAppReviewsStoreRequests: 'طلبات تقييم المتجر',
      KpiCardId.rewardsAdsWatchedTotal: 'الإعلانات المشاهدة',
      KpiCardId.rewardsGrantedTotal: 'المكافآت الممنوحة',
      KpiCardId.rewardsActiveUsersCount: 'مستخدمو المكافآت النشطون',
    },
    SupportedLanguage.es: {
      KpiCardId.usersTotalRegistered: 'Usuarios totales',
      KpiCardId.usersNewRegistrations: 'Nuevos registros',
      KpiCardId.usersActiveUsers: 'Usuarios activos',
      KpiCardId.contentHeadlinesTotalPublished: 'Titulares totales',
      KpiCardId.contentHeadlinesTotalViews: 'Vistas totales',
      KpiCardId.contentHeadlinesTotalLikes: 'Me gusta totales',
      KpiCardId.contentSourcesTotalSources: 'Fuentes totales',
      KpiCardId.contentSourcesNewSources: 'Nuevas fuentes',
      KpiCardId.contentSourcesTotalFollowers: 'Seguidores totales',
      KpiCardId.contentTopicsTotalTopics: 'Temas totales',
      KpiCardId.contentTopicsNewTopics: 'Nuevos temas',
      KpiCardId.contentTopicsTotalFollowers: 'Seguidores totales',
      KpiCardId.engagementsTotalReactions: 'Reacciones totales',
      KpiCardId.engagementsTotalComments: 'Comentarios totales',
      KpiCardId.engagementsAverageEngagementRate: 'Tasa de participación media',
      KpiCardId.engagementsReportsPending: 'Informes pendientes',
      KpiCardId.engagementsReportsResolved: 'Informes resueltos',
      KpiCardId.engagementsReportsAverageResolutionTime:
          'Tiempo medio de resolución',
      KpiCardId.engagementsAppReviewsTotalFeedback: 'Comentarios totales',
      KpiCardId.engagementsAppReviewsPositiveFeedback: 'Comentarios positivos',
      KpiCardId.engagementsAppReviewsStoreRequests: 'Solicitudes de tienda',
      KpiCardId.rewardsAdsWatchedTotal: 'Anuncios vistos',
      KpiCardId.rewardsGrantedTotal: 'Recompensas otorgadas',
      KpiCardId.rewardsActiveUsersCount: 'Usuarios de recompensas activos',
    },
    SupportedLanguage.fr: {
      KpiCardId.usersTotalRegistered: 'Utilisateurs totaux',
      KpiCardId.usersNewRegistrations: 'Nouvelles inscriptions',
      KpiCardId.usersActiveUsers: 'Utilisateurs actifs',
      KpiCardId.contentHeadlinesTotalPublished: 'Total des titres',
      KpiCardId.contentHeadlinesTotalViews: 'Vues totales',
      KpiCardId.contentHeadlinesTotalLikes: "J'aime totaux",
      KpiCardId.contentSourcesTotalSources: 'Sources totales',
      KpiCardId.contentSourcesNewSources: 'Nouvelles sources',
      KpiCardId.contentSourcesTotalFollowers: 'Abonnés totaux',
      KpiCardId.contentTopicsTotalTopics: 'Sujets totaux',
      KpiCardId.contentTopicsNewTopics: 'Nouveaux sujets',
      KpiCardId.contentTopicsTotalFollowers: 'Abonnés totaux',
      KpiCardId.engagementsTotalReactions: 'Réactions totales',
      KpiCardId.engagementsTotalComments: 'Commentaires totaux',
      KpiCardId.engagementsAverageEngagementRate: "Taux d'engagement moyen",
      KpiCardId.engagementsReportsPending: 'Rapports en attente',
      KpiCardId.engagementsReportsResolved: 'Rapports résolus',
      KpiCardId.engagementsReportsAverageResolutionTime:
          'Temps de résolution moyen',
      KpiCardId.engagementsAppReviewsTotalFeedback: 'Commentaires totaux',
      KpiCardId.engagementsAppReviewsPositiveFeedback: 'Commentaires positifs',
      KpiCardId.engagementsAppReviewsStoreRequests: 'Demandes de magasin',
      KpiCardId.rewardsAdsWatchedTotal: 'Publicités regardées',
      KpiCardId.rewardsGrantedTotal: 'Récompenses accordées',
      KpiCardId.rewardsActiveUsersCount: 'Utilisateurs de récompenses actifs',
    },
    SupportedLanguage.pt: {
      KpiCardId.usersTotalRegistered: 'Total de usuários',
      KpiCardId.usersNewRegistrations: 'Novos registros',
      KpiCardId.usersActiveUsers: 'Usuários ativos',
      KpiCardId.contentHeadlinesTotalPublished: 'Total de manchetes',
      KpiCardId.contentHeadlinesTotalViews: 'Total de visualizações',
      KpiCardId.contentHeadlinesTotalLikes: 'Total de curtidas',
      KpiCardId.contentSourcesTotalSources: 'Total de fontes',
      KpiCardId.contentSourcesNewSources: 'Novas fontes',
      KpiCardId.contentSourcesTotalFollowers: 'Total de seguidores',
      KpiCardId.contentTopicsTotalTopics: 'Total de tópicos',
      KpiCardId.contentTopicsNewTopics: 'Novos tópicos',
      KpiCardId.contentTopicsTotalFollowers: 'Total de seguidores',
      KpiCardId.engagementsTotalReactions: 'Total de reações',
      KpiCardId.engagementsTotalComments: 'Total de comentários',
      KpiCardId.engagementsAverageEngagementRate: 'Taxa média de engajamento',
      KpiCardId.engagementsReportsPending: 'Denúncias pendentes',
      KpiCardId.engagementsReportsResolved: 'Denúncias resolvidas',
      KpiCardId.engagementsReportsAverageResolutionTime:
          'Tempo médio de resolução',
      KpiCardId.engagementsAppReviewsTotalFeedback: 'Feedback total',
      KpiCardId.engagementsAppReviewsPositiveFeedback: 'Feedback positivo',
      KpiCardId.engagementsAppReviewsStoreRequests: 'Solicitações da loja',
      KpiCardId.rewardsAdsWatchedTotal: 'Anúncios assistidos',
      KpiCardId.rewardsGrantedTotal: 'Recompensas concedidas',
      KpiCardId.rewardsActiveUsersCount: 'Usuários de recompensas ativos',
    },
    SupportedLanguage.de: {
      KpiCardId.usersTotalRegistered: 'Benutzer gesamt',
      KpiCardId.usersNewRegistrations: 'Neuregistrierungen',
      KpiCardId.usersActiveUsers: 'Aktive Benutzer',
      KpiCardId.contentHeadlinesTotalPublished: 'Schlagzeilen gesamt',
      KpiCardId.contentHeadlinesTotalViews: 'Gesamtansichten',
      KpiCardId.contentHeadlinesTotalLikes: 'Likes gesamt',
      KpiCardId.contentSourcesTotalSources: 'Quellen gesamt',
      KpiCardId.contentSourcesNewSources: 'Neue Quellen',
      KpiCardId.contentSourcesTotalFollowers: 'Follower gesamt',
      KpiCardId.contentTopicsTotalTopics: 'Themen gesamt',
      KpiCardId.contentTopicsNewTopics: 'Neue Themen',
      KpiCardId.contentTopicsTotalFollowers: 'Follower gesamt',
      KpiCardId.engagementsTotalReactions: 'Reaktionen gesamt',
      KpiCardId.engagementsTotalComments: 'Kommentare gesamt',
      KpiCardId.engagementsAverageEngagementRate: 'Durchschn. Engagement-Rate',
      KpiCardId.engagementsReportsPending: 'Ausstehende Berichte',
      KpiCardId.engagementsReportsResolved: 'Gelöste Berichte',
      KpiCardId.engagementsReportsAverageResolutionTime:
          'Durchschn. Lösungszeit',
      KpiCardId.engagementsAppReviewsTotalFeedback: 'Feedback gesamt',
      KpiCardId.engagementsAppReviewsPositiveFeedback: 'Positives Feedback',
      KpiCardId.engagementsAppReviewsStoreRequests: 'Store-Anfragen',
      KpiCardId.rewardsAdsWatchedTotal: 'Angesehene Anzeigen',
      KpiCardId.rewardsGrantedTotal: 'Gewährte Belohnungen',
      KpiCardId.rewardsActiveUsersCount: 'Aktive Belohnungsbenutzer',
    },
    SupportedLanguage.it: {
      KpiCardId.usersTotalRegistered: 'Utenti totali',
      KpiCardId.usersNewRegistrations: 'Nuove registrazioni',
      KpiCardId.usersActiveUsers: 'Utenti attivi',
      KpiCardId.contentHeadlinesTotalPublished: 'Titoli totali',
      KpiCardId.contentHeadlinesTotalViews: 'Visualizzazioni totali',
      KpiCardId.contentHeadlinesTotalLikes: 'Mi piace totali',
      KpiCardId.contentSourcesTotalSources: 'Fonti totali',
      KpiCardId.contentSourcesNewSources: 'Nuove fonti',
      KpiCardId.contentSourcesTotalFollowers: 'Follower totali',
      KpiCardId.contentTopicsTotalTopics: 'Argomenti totali',
      KpiCardId.contentTopicsNewTopics: 'Nuovi argomenti',
      KpiCardId.contentTopicsTotalFollowers: 'Follower totali',
      KpiCardId.engagementsTotalReactions: 'Reazioni totali',
      KpiCardId.engagementsTotalComments: 'Commenti totali',
      KpiCardId.engagementsAverageEngagementRate:
          'Tasso di coinvolgimento medio',
      KpiCardId.engagementsReportsPending: 'Segnalazioni in sospeso',
      KpiCardId.engagementsReportsResolved: 'Segnalazioni risolte',
      KpiCardId.engagementsReportsAverageResolutionTime:
          'Tempo medio di risoluzione',
      KpiCardId.engagementsAppReviewsTotalFeedback: 'Feedback totale',
      KpiCardId.engagementsAppReviewsPositiveFeedback: 'Feedback positivo',
      KpiCardId.engagementsAppReviewsStoreRequests: 'Richieste dello store',
      KpiCardId.rewardsAdsWatchedTotal: 'Annunci guardati',
      KpiCardId.rewardsGrantedTotal: 'Ricompense concesse',
      KpiCardId.rewardsActiveUsersCount: 'Utenti premio attivi',
    },
    SupportedLanguage.zh: {
      KpiCardId.usersTotalRegistered: '用户总数',
      KpiCardId.usersNewRegistrations: '新注册',
      KpiCardId.usersActiveUsers: '活跃用户',
      KpiCardId.contentHeadlinesTotalPublished: '头条总数',
      KpiCardId.contentHeadlinesTotalViews: '总浏览量',
      KpiCardId.contentHeadlinesTotalLikes: '总点赞数',
      KpiCardId.contentSourcesTotalSources: '来源总数',
      KpiCardId.contentSourcesNewSources: '新来源',
      KpiCardId.contentSourcesTotalFollowers: '总关注者',
      KpiCardId.contentTopicsTotalTopics: '主题总数',
      KpiCardId.contentTopicsNewTopics: '新主题',
      KpiCardId.contentTopicsTotalFollowers: '总关注者',
      KpiCardId.engagementsTotalReactions: '总反应',
      KpiCardId.engagementsTotalComments: '总评论',
      KpiCardId.engagementsAverageEngagementRate: '平均参与率',
      KpiCardId.engagementsReportsPending: '待处理报告',
      KpiCardId.engagementsReportsResolved: '已解决报告',
      KpiCardId.engagementsReportsAverageResolutionTime: '平均解决时间',
      KpiCardId.engagementsAppReviewsTotalFeedback: '总反馈',
      KpiCardId.engagementsAppReviewsPositiveFeedback: '正面反馈',
      KpiCardId.engagementsAppReviewsStoreRequests: '商店请求',
      KpiCardId.rewardsAdsWatchedTotal: '已观看广告',
      KpiCardId.rewardsGrantedTotal: '已发放奖励',
      KpiCardId.rewardsActiveUsersCount: '活跃奖励用户',
    },
    SupportedLanguage.hi: {
      KpiCardId.usersTotalRegistered: 'कुल उपयोगकर्ता',
      KpiCardId.usersNewRegistrations: 'नए पंजीकरण',
      KpiCardId.usersActiveUsers: 'सक्रिय उपयोगकर्ता',
      KpiCardId.contentHeadlinesTotalPublished: 'कुल सुर्खियाँ',
      KpiCardId.contentHeadlinesTotalViews: 'कुल दृश्य',
      KpiCardId.contentHeadlinesTotalLikes: 'कुल पसंद',
      KpiCardId.contentSourcesTotalSources: 'कुल स्रोत',
      KpiCardId.contentSourcesNewSources: 'नए स्रोत',
      KpiCardId.contentSourcesTotalFollowers: 'कुल अनुयायी',
      KpiCardId.contentTopicsTotalTopics: 'कुल विषय',
      KpiCardId.contentTopicsNewTopics: 'नए विषय',
      KpiCardId.contentTopicsTotalFollowers: 'कुल अनुयायी',
      KpiCardId.engagementsTotalReactions: 'कुल प्रतिक्रियाएँ',
      KpiCardId.engagementsTotalComments: 'कुल टिप्पणियाँ',
      KpiCardId.engagementsAverageEngagementRate: 'औसत जुड़ाव दर',
      KpiCardId.engagementsReportsPending: 'लंबित रिपोर्ट',
      KpiCardId.engagementsReportsResolved: 'हल की गई रिपोर्ट',
      KpiCardId.engagementsReportsAverageResolutionTime: 'औसत समाधान समय',
      KpiCardId.engagementsAppReviewsTotalFeedback: 'कुल प्रतिक्रिया',
      KpiCardId.engagementsAppReviewsPositiveFeedback: 'सकारात्मक प्रतिक्रिया',
      KpiCardId.engagementsAppReviewsStoreRequests: 'स्टोर अनुरोध',
      KpiCardId.rewardsAdsWatchedTotal: 'देखे गए विज्ञापन',
      KpiCardId.rewardsGrantedTotal: 'दिए गए पुरस्कार',
      KpiCardId.rewardsActiveUsersCount: 'सक्रिय पुरस्कार उपयोगकर्ता',
    },
    SupportedLanguage.ja: {
      KpiCardId.usersTotalRegistered: '総ユーザー数',
      KpiCardId.usersNewRegistrations: '新規登録',
      KpiCardId.usersActiveUsers: 'アクティブユーザー',
      KpiCardId.contentHeadlinesTotalPublished: '総見出し数',
      KpiCardId.contentHeadlinesTotalViews: '総閲覧数',
      KpiCardId.contentHeadlinesTotalLikes: '総いいね数',
      KpiCardId.contentSourcesTotalSources: '総ソース数',
      KpiCardId.contentSourcesNewSources: '新しいソース',
      KpiCardId.contentSourcesTotalFollowers: '総フォロワー数',
      KpiCardId.contentTopicsTotalTopics: '総トピック数',
      KpiCardId.contentTopicsNewTopics: '新しいトピック',
      KpiCardId.contentTopicsTotalFollowers: '総フォロワー数',
      KpiCardId.engagementsTotalReactions: '総リアクション数',
      KpiCardId.engagementsTotalComments: '総コメント数',
      KpiCardId.engagementsAverageEngagementRate: '平均エンゲージメント率',
      KpiCardId.engagementsReportsPending: '保留中のレポート',
      KpiCardId.engagementsReportsResolved: '解決されたレポート',
      KpiCardId.engagementsReportsAverageResolutionTime: '平均解決時間',
      KpiCardId.engagementsAppReviewsTotalFeedback: '総フィードバック',
      KpiCardId.engagementsAppReviewsPositiveFeedback: 'ポジティブなフィードバック',
      KpiCardId.engagementsAppReviewsStoreRequests: 'ストアリクエスト',
      KpiCardId.rewardsAdsWatchedTotal: '視聴された広告',
      KpiCardId.rewardsGrantedTotal: '付与された報酬',
      KpiCardId.rewardsActiveUsersCount: 'アクティブな報酬ユーザー',
    },
  };

  /// A map containing the display labels for each ranked list card in all supported languages.
  static final Map<SupportedLanguage, Map<RankedListCardId, String>>
  _rankedListLabels = {
    SupportedLanguage.en: {
      RankedListCardId.overviewHeadlinesMostViewed: 'Most Viewed Headlines',
      RankedListCardId.overviewHeadlinesMostLiked: 'Most Liked Headlines',
      RankedListCardId.overviewSourcesMostFollowed: 'Most Followed Sources',
      RankedListCardId.overviewTopicsMostFollowed: 'Most Followed Topics',
    },
    SupportedLanguage.ar: {
      RankedListCardId.overviewHeadlinesMostViewed: 'العناوين الأكثر مشاهدة',
      RankedListCardId.overviewHeadlinesMostLiked: 'العناوين الأكثر إعجابًا',
      RankedListCardId.overviewSourcesMostFollowed: 'المصادر الأكثر متابعة',
      RankedListCardId.overviewTopicsMostFollowed: 'المواضيع الأكثر متابعة',
    },
    SupportedLanguage.es: {
      RankedListCardId.overviewHeadlinesMostViewed: 'Titulares más vistos',
      RankedListCardId.overviewHeadlinesMostLiked: 'Titulares con más me gusta',
      RankedListCardId.overviewSourcesMostFollowed: 'Fuentes más seguidas',
      RankedListCardId.overviewTopicsMostFollowed: 'Temas más seguidos',
    },
    SupportedLanguage.fr: {
      RankedListCardId.overviewHeadlinesMostViewed: 'Titres les plus consultés',
      RankedListCardId.overviewHeadlinesMostLiked: 'Titres les plus aimés',
      RankedListCardId.overviewSourcesMostFollowed: 'Sources les plus suivies',
      RankedListCardId.overviewTopicsMostFollowed: 'Sujets les plus suivis',
    },
    SupportedLanguage.pt: {
      RankedListCardId.overviewHeadlinesMostViewed:
          'Manchetes mais visualizadas',
      RankedListCardId.overviewHeadlinesMostLiked: 'Manchetes mais curtidas',
      RankedListCardId.overviewSourcesMostFollowed: 'Fontes mais seguidas',
      RankedListCardId.overviewTopicsMostFollowed: 'Tópicos mais seguidos',
    },
    SupportedLanguage.de: {
      RankedListCardId.overviewHeadlinesMostViewed:
          'Meistgesehene Schlagzeilen',
      RankedListCardId.overviewHeadlinesMostLiked: 'Beliebteste Schlagzeilen',
      RankedListCardId.overviewSourcesMostFollowed: 'Meistgefolgte Quellen',
      RankedListCardId.overviewTopicsMostFollowed: 'Meistgefolgte Themen',
    },
    SupportedLanguage.it: {
      RankedListCardId.overviewHeadlinesMostViewed: 'Titoli più visti',
      RankedListCardId.overviewHeadlinesMostLiked: 'Titoli più piaciuti',
      RankedListCardId.overviewSourcesMostFollowed: 'Fonti più seguite',
      RankedListCardId.overviewTopicsMostFollowed: 'Argomenti più seguiti',
    },
    SupportedLanguage.zh: {
      RankedListCardId.overviewHeadlinesMostViewed: '浏览最多的头条新闻',
      RankedListCardId.overviewHeadlinesMostLiked: '最受欢迎的头条新闻',
      RankedListCardId.overviewSourcesMostFollowed: '关注最多的来源',
      RankedListCardId.overviewTopicsMostFollowed: '关注最多的主题',
    },
    SupportedLanguage.hi: {
      RankedListCardId.overviewHeadlinesMostViewed:
          'सबसे ज्यादा देखी गई सुर्खियाँ',
      RankedListCardId.overviewHeadlinesMostLiked:
          'सबसे ज्यादा पसंद की गई सुर्खियाँ',
      RankedListCardId.overviewSourcesMostFollowed:
          'सबसे ज्यादा फॉलो किए जाने वाले स्रोत',
      RankedListCardId.overviewTopicsMostFollowed:
          'सबसे ज्यादा फॉलो किए जाने वाले विषय',
    },
    SupportedLanguage.ja: {
      RankedListCardId.overviewHeadlinesMostViewed: '最も閲覧された見出し',
      RankedListCardId.overviewHeadlinesMostLiked: '最もいいねされた見出し',
      RankedListCardId.overviewSourcesMostFollowed: '最もフォローされているソース',
      RankedListCardId.overviewTopicsMostFollowed: '最もフォローされているトピック',
    },
  };

  /// A map containing the display labels for each chart card in all supported languages.
  static final Map<SupportedLanguage, Map<ChartCardId, String>> _chartLabels = {
    SupportedLanguage.en: {
      // Users
      ChartCardId.usersRegistrationsOverTime: 'Registrations Over Time',
      ChartCardId.usersActiveUsersOverTime: 'Active Users Over Time',
      ChartCardId.usersTierDistribution: 'User Tier Distribution',
      // Headlines
      ChartCardId.contentHeadlinesViewsOverTime: 'Views Over Time',
      ChartCardId.contentHeadlinesLikesOverTime: 'Likes Over Time',
      ChartCardId.contentHeadlinesViewsByTopic: 'Views by Topic',
      // Sources
      ChartCardId.contentSourcesHeadlinesPublishedOverTime:
          'Headlines Published Over Time',
      ChartCardId.contentSourcesStatusDistribution:
          'Source Status Distribution',
      ChartCardId.contentSourcesEngagementByType: 'Engagement by Source Type',
      // Topics
      ChartCardId.contentHeadlinesBreakingNewsDistribution:
          'Breaking News Distribution',
      ChartCardId.contentTopicsHeadlinesPublishedOverTime:
          'Headlines Published Over Time',
      ChartCardId.contentTopicsEngagementByTopic: 'Engagement by Topic',
      // Engagements
      ChartCardId.engagementsReactionsOverTime: 'Reactions Over Time',
      ChartCardId.engagementsCommentsOverTime: 'Comments Over Time',
      ChartCardId.engagementsReactionsByType: 'Reactions by Type',
      // Reports
      ChartCardId.engagementsReportsSubmittedOverTime:
          'Reports Submitted Over Time',
      ChartCardId.engagementsReportsResolutionTimeOverTime:
          'Avg. Resolution Time Over Time',
      ChartCardId.engagementsReportsByReason: 'Reports by Reason',
      // App Reviews
      ChartCardId.engagementsAppReviewsFeedbackOverTime: 'Feedback Over Time',
      ChartCardId.engagementsAppReviewsPositiveVsNegative:
          'Positive vs. Negative Feedback',
      ChartCardId.engagementsAppReviewsStoreRequestsOverTime:
          'Store Requests Over Time',
      ChartCardId.rewardsAdsWatchedOverTime: 'Ads Watched Over Time',
      ChartCardId.rewardsGrantedOverTime: 'Rewards Granted Over Time',
      ChartCardId.rewardsActiveByType: 'Active Rewards by Type',
    },
    SupportedLanguage.ar: {
      // Users
      ChartCardId.usersRegistrationsOverTime: 'التسجيلات عبر الزمن',
      ChartCardId.usersActiveUsersOverTime: 'المستخدمون النشطون عبر الزمن',
      ChartCardId.usersTierDistribution: 'توزيع مستويات المستخدمين',
      // Headlines
      ChartCardId.contentHeadlinesViewsOverTime: 'المشاهدات عبر الزمن',
      ChartCardId.contentHeadlinesLikesOverTime: 'الإعجابات عبر الزمن',
      ChartCardId.contentHeadlinesViewsByTopic: 'المشاهدات حسب الموضوع',
      // Sources
      ChartCardId.contentSourcesHeadlinesPublishedOverTime:
          'العناوين المنشورة عبر الزمن',
      ChartCardId.contentSourcesStatusDistribution: 'توزيع حالة المصادر',
      ChartCardId.contentSourcesEngagementByType: 'التفاعل حسب نوع المصدر',
      // Topics
      ChartCardId.contentHeadlinesBreakingNewsDistribution:
          'توزيع الأخبار العاجلة',
      ChartCardId.contentTopicsHeadlinesPublishedOverTime:
          'العناوين المنشورة عبر الزمن',
      ChartCardId.contentTopicsEngagementByTopic: 'التفاعل حسب الموضوع',
      // Engagements
      ChartCardId.engagementsReactionsOverTime: 'التفاعلات عبر الزمن',
      ChartCardId.engagementsCommentsOverTime: 'التعليقات عبر الزمن',
      ChartCardId.engagementsReactionsByType: 'التفاعلات حسب النوع',
      // Reports
      ChartCardId.engagementsReportsSubmittedOverTime:
          'التقارير المقدمة عبر الزمن',
      ChartCardId.engagementsReportsResolutionTimeOverTime:
          'متوسط وقت حل التقارير عبر الزمن',
      ChartCardId.engagementsReportsByReason: 'التقارير حسب السبب',
      // App Reviews
      ChartCardId.engagementsAppReviewsFeedbackOverTime: 'التقييمات عبر الزمن',
      ChartCardId.engagementsAppReviewsPositiveVsNegative:
          'التقييمات الإيجابية مقابل السلبية',
      ChartCardId.engagementsAppReviewsStoreRequestsOverTime:
          'طلبات تقييم المتجر عبر الزمن',
      ChartCardId.rewardsAdsWatchedOverTime: 'الإعلانات المشاهدة عبر الزمن',
      ChartCardId.rewardsGrantedOverTime: 'المكافآت الممنوحة عبر الزمن',
      ChartCardId.rewardsActiveByType: 'المكافآت النشطة حسب النوع',
    },
    SupportedLanguage.es: {
      ChartCardId.usersRegistrationsOverTime: 'Registros a lo largo del tiempo',
      ChartCardId.usersActiveUsersOverTime:
          'Usuarios activos a lo largo del tiempo',
      ChartCardId.usersTierDistribution: 'Distribución de niveles de usuario',
      ChartCardId.contentHeadlinesViewsOverTime: 'Vistas a lo largo del tiempo',
      ChartCardId.contentHeadlinesLikesOverTime:
          'Me gusta a lo largo del tiempo',
      ChartCardId.contentHeadlinesViewsByTopic: 'Vistas por tema',
      ChartCardId.contentSourcesHeadlinesPublishedOverTime:
          'Titulares publicados a lo largo del tiempo',
      ChartCardId.contentSourcesStatusDistribution:
          'Distribución del estado de la fuente',
      ChartCardId.contentSourcesEngagementByType:
          'Participación por tipo de fuente',
      ChartCardId.contentHeadlinesBreakingNewsDistribution:
          'Distribución de noticias de última hora',
      ChartCardId.contentTopicsHeadlinesPublishedOverTime:
          'Titulares publicados a lo largo del tiempo',
      ChartCardId.contentTopicsEngagementByTopic: 'Participación por tema',
      ChartCardId.engagementsReactionsOverTime:
          'Reacciones a lo largo del tiempo',
      ChartCardId.engagementsCommentsOverTime:
          'Comentarios a lo largo del tiempo',
      ChartCardId.engagementsReactionsByType: 'Reacciones por tipo',
      ChartCardId.engagementsReportsSubmittedOverTime:
          'Informes enviados a lo largo del tiempo',
      ChartCardId.engagementsReportsResolutionTimeOverTime:
          'Tiempo medio de resolución a lo largo del tiempo',
      ChartCardId.engagementsReportsByReason: 'Informes por motivo',
      ChartCardId.engagementsAppReviewsFeedbackOverTime:
          'Comentarios a lo largo del tiempo',
      ChartCardId.engagementsAppReviewsPositiveVsNegative:
          'Comentarios positivos vs. negativos',
      ChartCardId.engagementsAppReviewsStoreRequestsOverTime:
          'Solicitudes de tienda a lo largo del tiempo',
      ChartCardId.rewardsAdsWatchedOverTime:
          'Anuncios vistos a lo largo del tiempo',
      ChartCardId.rewardsGrantedOverTime:
          'Recompensas otorgadas a lo largo del tiempo',
      ChartCardId.rewardsActiveByType: 'Recompensas activas por tipo',
    },
    SupportedLanguage.fr: {
      ChartCardId.usersRegistrationsOverTime: 'Inscriptions au fil du temps',
      ChartCardId.usersActiveUsersOverTime:
          'Utilisateurs actifs au fil du temps',
      ChartCardId.usersTierDistribution:
          "Répartition des niveaux d'utilisateurs",
      ChartCardId.contentHeadlinesViewsOverTime: 'Vues au fil du temps',
      ChartCardId.contentHeadlinesLikesOverTime: "J'aime au fil du temps",
      ChartCardId.contentHeadlinesViewsByTopic: 'Vues par sujet',
      ChartCardId.contentSourcesHeadlinesPublishedOverTime:
          'Titres publiés au fil du temps',
      ChartCardId.contentSourcesStatusDistribution:
          'Répartition du statut des sources',
      ChartCardId.contentSourcesEngagementByType:
          'Engagement par type de source',
      ChartCardId.contentHeadlinesBreakingNewsDistribution:
          'Répartition des dernières nouvelles',
      ChartCardId.contentTopicsHeadlinesPublishedOverTime:
          'Titres publiés au fil du temps',
      ChartCardId.contentTopicsEngagementByTopic: 'Engagement par sujet',
      ChartCardId.engagementsReactionsOverTime: 'Réactions au fil du temps',
      ChartCardId.engagementsCommentsOverTime: 'Commentaires au fil du temps',
      ChartCardId.engagementsReactionsByType: 'Réactions par type',
      ChartCardId.engagementsReportsSubmittedOverTime:
          'Rapports soumis au fil du temps',
      ChartCardId.engagementsReportsResolutionTimeOverTime:
          'Temps de résolution moyen au fil du temps',
      ChartCardId.engagementsReportsByReason: 'Rapports par raison',
      ChartCardId.engagementsAppReviewsFeedbackOverTime:
          'Commentaires au fil du temps',
      ChartCardId.engagementsAppReviewsPositiveVsNegative:
          'Commentaires positifs vs négatifs',
      ChartCardId.engagementsAppReviewsStoreRequestsOverTime:
          'Demandes de magasin au fil du temps',
      ChartCardId.rewardsAdsWatchedOverTime:
          'Publicités regardées au fil du temps',
      ChartCardId.rewardsGrantedOverTime:
          'Récompenses accordées au fil du temps',
      ChartCardId.rewardsActiveByType: 'Récompenses actives par type',
    },
    SupportedLanguage.pt: {
      ChartCardId.usersRegistrationsOverTime: 'Registros ao longo do tempo',
      ChartCardId.usersActiveUsersOverTime: 'Usuários ativos ao longo do tempo',
      ChartCardId.usersTierDistribution: 'Distribuição de níveis de usuário',
      ChartCardId.contentHeadlinesViewsOverTime:
          'Visualizações ao longo do tempo',
      ChartCardId.contentHeadlinesLikesOverTime: 'Curtidas ao longo do tempo',
      ChartCardId.contentHeadlinesViewsByTopic: 'Visualizações por tópico',
      ChartCardId.contentSourcesHeadlinesPublishedOverTime:
          'Manchetes publicadas ao longo do tempo',
      ChartCardId.contentSourcesStatusDistribution:
          'Distribuição de status da fonte',
      ChartCardId.contentSourcesEngagementByType:
          'Engajamento por tipo de fonte',
      ChartCardId.contentHeadlinesBreakingNewsDistribution:
          'Distribuição de notícias de última hora',
      ChartCardId.contentTopicsHeadlinesPublishedOverTime:
          'Manchetes publicadas ao longo do tempo',
      ChartCardId.contentTopicsEngagementByTopic: 'Engajamento por tópico',
      ChartCardId.engagementsReactionsOverTime: 'Reações ao longo do tempo',
      ChartCardId.engagementsCommentsOverTime: 'Comentários ao longo do tempo',
      ChartCardId.engagementsReactionsByType: 'Reações por tipo',
      ChartCardId.engagementsReportsSubmittedOverTime:
          'Denúncias enviadas ao longo do tempo',
      ChartCardId.engagementsReportsResolutionTimeOverTime:
          'Tempo médio de resolução ao longo do tempo',
      ChartCardId.engagementsReportsByReason: 'Denúncias por motivo',
      ChartCardId.engagementsAppReviewsFeedbackOverTime:
          'Feedback ao longo do tempo',
      ChartCardId.engagementsAppReviewsPositiveVsNegative:
          'Feedback positivo vs. negativo',
      ChartCardId.engagementsAppReviewsStoreRequestsOverTime:
          'Solicitações da loja ao longo do tempo',
      ChartCardId.rewardsAdsWatchedOverTime:
          'Anúncios assistidos ao longo do tempo',
      ChartCardId.rewardsGrantedOverTime:
          'Recompensas concedidas ao longo do tempo',
      ChartCardId.rewardsActiveByType: 'Recompensas ativas por tipo',
    },
    SupportedLanguage.de: {
      ChartCardId.usersRegistrationsOverTime: 'Registrierungen im Zeitverlauf',
      ChartCardId.usersActiveUsersOverTime: 'Aktive Benutzer im Zeitverlauf',
      ChartCardId.usersTierDistribution: 'Verteilung der Benutzerebenen',
      ChartCardId.contentHeadlinesViewsOverTime: 'Ansichten im Zeitverlauf',
      ChartCardId.contentHeadlinesLikesOverTime: 'Likes im Zeitverlauf',
      ChartCardId.contentHeadlinesViewsByTopic: 'Ansichten nach Thema',
      ChartCardId.contentSourcesHeadlinesPublishedOverTime:
          'Veröffentlichte Schlagzeilen im Zeitverlauf',
      ChartCardId.contentSourcesStatusDistribution:
          'Verteilung des Quellenstatus',
      ChartCardId.contentSourcesEngagementByType: 'Engagement nach Quellentyp',
      ChartCardId.contentHeadlinesBreakingNewsDistribution:
          'Verteilung der Eilmeldungen',
      ChartCardId.contentTopicsHeadlinesPublishedOverTime:
          'Veröffentlichte Schlagzeilen im Zeitverlauf',
      ChartCardId.contentTopicsEngagementByTopic: 'Engagement nach Thema',
      ChartCardId.engagementsReactionsOverTime: 'Reaktionen im Zeitverlauf',
      ChartCardId.engagementsCommentsOverTime: 'Kommentare im Zeitverlauf',
      ChartCardId.engagementsReactionsByType: 'Reaktionen nach Typ',
      ChartCardId.engagementsReportsSubmittedOverTime:
          'Eingereichte Berichte im Zeitverlauf',
      ChartCardId.engagementsReportsResolutionTimeOverTime:
          'Durchschn. Lösungszeit im Zeitverlauf',
      ChartCardId.engagementsReportsByReason: 'Berichte nach Grund',
      ChartCardId.engagementsAppReviewsFeedbackOverTime:
          'Feedback im Zeitverlauf',
      ChartCardId.engagementsAppReviewsPositiveVsNegative:
          'Positives vs. Negatives Feedback',
      ChartCardId.engagementsAppReviewsStoreRequestsOverTime:
          'Store-Anfragen im Zeitverlauf',
      ChartCardId.rewardsAdsWatchedOverTime:
          'Angesehene Anzeigen im Zeitverlauf',
      ChartCardId.rewardsGrantedOverTime: 'Gewährte Belohnungen im Zeitverlauf',
      ChartCardId.rewardsActiveByType: 'Aktive Belohnungen nach Typ',
    },
    SupportedLanguage.it: {
      ChartCardId.usersRegistrationsOverTime: 'Registrazioni nel tempo',
      ChartCardId.usersActiveUsersOverTime: 'Utenti attivi nel tempo',
      ChartCardId.usersTierDistribution: 'Distribuzione dei livelli utente',
      ChartCardId.contentHeadlinesViewsOverTime: 'Visualizzazioni nel tempo',
      ChartCardId.contentHeadlinesLikesOverTime: 'Mi piace nel tempo',
      ChartCardId.contentHeadlinesViewsByTopic: 'Visualizzazioni per argomento',
      ChartCardId.contentSourcesHeadlinesPublishedOverTime:
          'Titoli pubblicati nel tempo',
      ChartCardId.contentSourcesStatusDistribution:
          'Distribuzione dello stato della fonte',
      ChartCardId.contentSourcesEngagementByType:
          'Coinvolgimento per tipo di fonte',
      ChartCardId.contentHeadlinesBreakingNewsDistribution:
          'Distribuzione delle ultime notizie',
      ChartCardId.contentTopicsHeadlinesPublishedOverTime:
          'Titoli pubblicati nel tempo',
      ChartCardId.contentTopicsEngagementByTopic:
          'Coinvolgimento per argomento',
      ChartCardId.engagementsReactionsOverTime: 'Reazioni nel tempo',
      ChartCardId.engagementsCommentsOverTime: 'Commenti nel tempo',
      ChartCardId.engagementsReactionsByType: 'Reazioni per tipo',
      ChartCardId.engagementsReportsSubmittedOverTime:
          'Segnalazioni inviate nel tempo',
      ChartCardId.engagementsReportsResolutionTimeOverTime:
          'Tempo medio di risoluzione nel tempo',
      ChartCardId.engagementsReportsByReason: 'Segnalazioni per motivo',
      ChartCardId.engagementsAppReviewsFeedbackOverTime: 'Feedback nel tempo',
      ChartCardId.engagementsAppReviewsPositiveVsNegative:
          'Feedback positivo vs. negativo',
      ChartCardId.engagementsAppReviewsStoreRequestsOverTime:
          'Richieste dello store nel tempo',
      ChartCardId.rewardsAdsWatchedOverTime: 'Annunci guardati nel tempo',
      ChartCardId.rewardsGrantedOverTime: 'Ricompense concesse nel tempo',
      ChartCardId.rewardsActiveByType: 'Ricompense attive per tipo',
    },
    SupportedLanguage.zh: {
      ChartCardId.usersRegistrationsOverTime: '随时间变化的注册',
      ChartCardId.usersActiveUsersOverTime: '随时间变化的活跃用户',
      ChartCardId.usersTierDistribution: '用户层级分布',
      ChartCardId.contentHeadlinesViewsOverTime: '随时间变化的浏览量',
      ChartCardId.contentHeadlinesLikesOverTime: '随时间变化的点赞数',
      ChartCardId.contentHeadlinesViewsByTopic: '按主题浏览',
      ChartCardId.contentSourcesHeadlinesPublishedOverTime: '随时间发布的头条新闻',
      ChartCardId.contentSourcesStatusDistribution: '来源状态分布',
      ChartCardId.contentSourcesEngagementByType: '按来源类型参与',
      ChartCardId.contentHeadlinesBreakingNewsDistribution: '突发新闻分布',
      ChartCardId.contentTopicsHeadlinesPublishedOverTime: '随时间发布的头条新闻',
      ChartCardId.contentTopicsEngagementByTopic: '按主题参与',
      ChartCardId.engagementsReactionsOverTime: '随时间变化的反应',
      ChartCardId.engagementsCommentsOverTime: '随时间变化的评论',
      ChartCardId.engagementsReactionsByType: '按类型反应',
      ChartCardId.engagementsReportsSubmittedOverTime: '随时间提交的报告',
      ChartCardId.engagementsReportsResolutionTimeOverTime: '随时间变化的平均解决时间',
      ChartCardId.engagementsReportsByReason: '按原因报告',
      ChartCardId.engagementsAppReviewsFeedbackOverTime: '随时间变化的反馈',
      ChartCardId.engagementsAppReviewsPositiveVsNegative: '正面与负面反馈',
      ChartCardId.engagementsAppReviewsStoreRequestsOverTime: '随时间变化的商店请求',
      ChartCardId.rewardsAdsWatchedOverTime: '随时间观看的广告',
      ChartCardId.rewardsGrantedOverTime: '随时间发放的奖励',
      ChartCardId.rewardsActiveByType: '按类型活跃奖励',
    },
    SupportedLanguage.hi: {
      ChartCardId.usersRegistrationsOverTime: 'समय के साथ पंजीकरण',
      ChartCardId.usersActiveUsersOverTime: 'समय के साथ सक्रिय उपयोगकर्ता',
      ChartCardId.usersTierDistribution: 'उपयोगकर्ता स्तर वितरण',
      ChartCardId.contentHeadlinesViewsOverTime: 'समय के साथ दृश्य',
      ChartCardId.contentHeadlinesLikesOverTime: 'समय के साथ पसंद',
      ChartCardId.contentHeadlinesViewsByTopic: 'विषय के अनुसार दृश्य',
      ChartCardId.contentSourcesHeadlinesPublishedOverTime:
          'समय के साथ प्रकाशित सुर्खियाँ',
      ChartCardId.contentSourcesStatusDistribution: 'स्रोत स्थिति वितरण',
      ChartCardId.contentSourcesEngagementByType: 'स्रोत प्रकार द्वारा जुड़ाव',
      ChartCardId.contentHeadlinesBreakingNewsDistribution:
          'ब्रेकिंग न्यूज़ वितरण',
      ChartCardId.contentTopicsHeadlinesPublishedOverTime:
          'समय के साथ प्रकाशित सुर्खियाँ',
      ChartCardId.contentTopicsEngagementByTopic: 'विषय द्वारा जुड़ाव',
      ChartCardId.engagementsReactionsOverTime: 'समय के साथ प्रतिक्रियाएँ',
      ChartCardId.engagementsCommentsOverTime: 'समय के साथ टिप्पणियाँ',
      ChartCardId.engagementsReactionsByType: 'प्रकार द्वारा प्रतिक्रियाएँ',
      ChartCardId.engagementsReportsSubmittedOverTime:
          'समय के साथ प्रस्तुत रिपोर्ट',
      ChartCardId.engagementsReportsResolutionTimeOverTime:
          'समय के साथ औसत समाधान समय',
      ChartCardId.engagementsReportsByReason: 'कारण द्वारा रिपोर्ट',
      ChartCardId.engagementsAppReviewsFeedbackOverTime:
          'समय के साथ प्रतिक्रिया',
      ChartCardId.engagementsAppReviewsPositiveVsNegative:
          'सकारात्मक बनाम नकारात्मक प्रतिक्रिया',
      ChartCardId.engagementsAppReviewsStoreRequestsOverTime:
          'समय के साथ स्टोर अनुरोध',
      ChartCardId.rewardsAdsWatchedOverTime: 'समय के साथ देखे गए विज्ञापन',
      ChartCardId.rewardsGrantedOverTime: 'समय के साथ दिए गए पुरस्कार',
      ChartCardId.rewardsActiveByType: 'प्रकार द्वारा सक्रिय पुरस्कार',
    },
    SupportedLanguage.ja: {
      ChartCardId.usersRegistrationsOverTime: '時間の経過に伴う登録',
      ChartCardId.usersActiveUsersOverTime: '時間の経過に伴うアクティブユーザー',
      ChartCardId.usersTierDistribution: 'ユーザー層の分布',
      ChartCardId.contentHeadlinesViewsOverTime: '時間の経過に伴う閲覧数',
      ChartCardId.contentHeadlinesLikesOverTime: '時間の経過に伴ういいね数',
      ChartCardId.contentHeadlinesViewsByTopic: 'トピック別の閲覧数',
      ChartCardId.contentSourcesHeadlinesPublishedOverTime: '時間の経過に伴う公開された見出し',
      ChartCardId.contentSourcesStatusDistribution: 'ソースステータスの分布',
      ChartCardId.contentSourcesEngagementByType: 'ソースタイプ別のエンゲージメント',
      ChartCardId.contentHeadlinesBreakingNewsDistribution: 'ニュース速報の分布',
      ChartCardId.contentTopicsHeadlinesPublishedOverTime: '時間の経過に伴う公開された見出し',
      ChartCardId.contentTopicsEngagementByTopic: 'トピック別のエンゲージメント',
      ChartCardId.engagementsReactionsOverTime: '時間の経過に伴うリアクション',
      ChartCardId.engagementsCommentsOverTime: '時間の経過に伴うコメント',
      ChartCardId.engagementsReactionsByType: 'タイプ別のリアクション',
      ChartCardId.engagementsReportsSubmittedOverTime: '時間の経過に伴う提出されたレポート',
      ChartCardId.engagementsReportsResolutionTimeOverTime: '時間の経過に伴う平均解決時間',
      ChartCardId.engagementsReportsByReason: '理由別のレポート',
      ChartCardId.engagementsAppReviewsFeedbackOverTime: '時間の経過に伴うフィードバック',
      ChartCardId.engagementsAppReviewsPositiveVsNegative:
          'ポジティブなフィードバックとネガティブなフィードバック',
      ChartCardId.engagementsAppReviewsStoreRequestsOverTime:
          '時間の経過に伴うストアリクエスト',
      ChartCardId.rewardsAdsWatchedOverTime: '時間の経過に伴う視聴された広告',
      ChartCardId.rewardsGrantedOverTime: '時間の経過に伴う付与された報酬',
      ChartCardId.rewardsActiveByType: 'タイプ別のアクティブな報酬',
    },
  };
}
