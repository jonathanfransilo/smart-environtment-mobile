class ArtikelModel {
  final int id;
  final String title;
  final String? slug;
  final String? excerpt;
  final String content;
  final String? imageUrl;
  final String? author;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isFeatured;
  final int viewCount;
  final List<String>? tags;

  ArtikelModel({
    required this.id,
    required this.title,
    this.slug,
    this.excerpt,
    required this.content,
    this.imageUrl,
    this.author,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
    this.isFeatured = false,
    this.viewCount = 0,
    this.tags,
  });

  factory ArtikelModel.fromJson(Map<String, dynamic> json) {
    return ArtikelModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'],
      // API menggunakan 'summary' bukan 'excerpt'
      excerpt: json['summary'] ?? json['excerpt'],
      content: json['content'] ?? '',
      // API menggunakan 'featured_image_url' bukan 'image_url'
      imageUrl:
          json['featured_image_url'] ??
          json['image_url'] ??
          json['imageUrl'] ??
          json['image'],
      author: json['author'],
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      isFeatured: json['is_featured'] ?? json['isFeatured'] ?? false,
      viewCount: json['view_count'] ?? json['viewCount'] ?? 0,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] is List ? json['tags'] : [])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'excerpt': excerpt,
      'content': content,
      'image_url': imageUrl,
      'author': author,
      'published_at': publishedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_featured': isFeatured,
      'view_count': viewCount,
      'tags': tags,
    };
  }
}

class ArtikelListResponse {
  final List<ArtikelModel> data;
  final PaginationMeta meta;

  ArtikelListResponse({required this.data, required this.meta});

  factory ArtikelListResponse.fromJson(Map<String, dynamic> json) {
    // Handle different response structures
    List<ArtikelModel> articles = [];

    // Try to get data from 'data' field
    if (json['data'] != null) {
      if (json['data'] is List) {
        articles = (json['data'] as List)
            .map((item) => ArtikelModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }
    // If no 'data' field but has 'articles' field
    else if (json['articles'] != null && json['articles'] is List) {
      articles = (json['articles'] as List)
          .map((item) => ArtikelModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Get pagination meta
    Map<String, dynamic> metaData = {};
    if (json['meta'] != null) {
      metaData = json['meta'] as Map<String, dynamic>;
    } else if (json['pagination'] != null) {
      metaData = json['pagination'] as Map<String, dynamic>;
    }

    return ArtikelListResponse(
      data: articles,
      meta: PaginationMeta.fromJson(metaData),
    );
  }
}

class PaginationMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int from;
  final int to;

  PaginationMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.from,
    required this.to,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: json['current_page'] ?? json['currentPage'] ?? 1,
      lastPage: json['last_page'] ?? json['lastPage'] ?? 1,
      perPage: json['per_page'] ?? json['perPage'] ?? 10,
      total: json['total'] ?? 0,
      from: json['from'] ?? 0,
      to: json['to'] ?? 0,
    );
  }
}
