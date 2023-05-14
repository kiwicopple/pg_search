export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json }
  | Json[]

export interface Database {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          operationName?: string
          query?: string
          variables?: Json
          extensions?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      context: {
        Row: {
          checksum: string | null
          id: string
          meta: Json | null
          updated_at: string
        }
        Insert: {
          checksum?: string | null
          id: string
          meta?: Json | null
          updated_at?: string
        }
        Update: {
          checksum?: string | null
          id?: string
          meta?: Json | null
          updated_at?: string
        }
      }
      documents: {
        Row: {
          content: string
          context_id: string
          fts: unknown | null
          id: string
          meta: Json | null
          updated_at: string
        }
        Insert: {
          content: string
          context_id: string
          fts?: unknown | null
          id?: string
          meta?: Json | null
          updated_at?: string
        }
        Update: {
          content?: string
          context_id?: string
          fts?: unknown | null
          id?: string
          meta?: Json | null
          updated_at?: string
        }
      }
      queries: {
        Row: {
          created_at: string
          feedback: Json | null
          id: string
          query: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          feedback?: Json | null
          id?: string
          query: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          feedback?: Json | null
          id?: string
          query?: string
          user_id?: string | null
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      chunks: {
        Args: {
          content: string
          delimiter: string
        }
        Returns: string[]
      }
      content_checksum: {
        Args: {
          content: string
        }
        Returns: string
      }
      ivfflathandler: {
        Args: {
          "": unknown
        }
        Returns: unknown
      }
      load_documents: {
        Args: {
          id: string
          content: string
          meta: Json
          documents: Json
        }
        Returns: {
          checksum: string | null
          id: string
          meta: Json | null
          updated_at: string
        }
      }
      text_search: {
        Args: {
          query: string
        }
        Returns: {
          document_id: string
          document_meta: Json
          content: string
          context_id: string
          context_meta: Json
          query_id: string
        }[]
      }
      vector_avg: {
        Args: {
          "": number[]
        }
        Returns: unknown
      }
      vector_dims: {
        Args: {
          "": unknown
        }
        Returns: number
      }
      vector_norm: {
        Args: {
          "": unknown
        }
        Returns: number
      }
      vector_out: {
        Args: {
          "": unknown
        }
        Returns: unknown
      }
      vector_send: {
        Args: {
          "": unknown
        }
        Returns: string
      }
      vector_typmod_in: {
        Args: {
          "": unknown[]
        }
        Returns: number
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  storage: {
    Tables: {
      buckets: {
        Row: {
          created_at: string | null
          id: string
          name: string
          owner: string | null
          public: boolean | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          id: string
          name: string
          owner?: string | null
          public?: boolean | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          name?: string
          owner?: string | null
          public?: boolean | null
          updated_at?: string | null
        }
      }
      migrations: {
        Row: {
          executed_at: string | null
          hash: string
          id: number
          name: string
        }
        Insert: {
          executed_at?: string | null
          hash: string
          id: number
          name: string
        }
        Update: {
          executed_at?: string | null
          hash?: string
          id?: number
          name?: string
        }
      }
      objects: {
        Row: {
          bucket_id: string | null
          created_at: string | null
          id: string
          last_accessed_at: string | null
          metadata: Json | null
          name: string | null
          owner: string | null
          path_tokens: string[] | null
          updated_at: string | null
        }
        Insert: {
          bucket_id?: string | null
          created_at?: string | null
          id?: string
          last_accessed_at?: string | null
          metadata?: Json | null
          name?: string | null
          owner?: string | null
          path_tokens?: string[] | null
          updated_at?: string | null
        }
        Update: {
          bucket_id?: string | null
          created_at?: string | null
          id?: string
          last_accessed_at?: string | null
          metadata?: Json | null
          name?: string | null
          owner?: string | null
          path_tokens?: string[] | null
          updated_at?: string | null
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      extension: {
        Args: {
          name: string
        }
        Returns: string
      }
      filename: {
        Args: {
          name: string
        }
        Returns: string
      }
      foldername: {
        Args: {
          name: string
        }
        Returns: string[]
      }
      get_size_by_bucket: {
        Args: Record<PropertyKey, never>
        Returns: {
          size: number
          bucket_id: string
        }[]
      }
      search: {
        Args: {
          prefix: string
          bucketname: string
          limits?: number
          levels?: number
          offsets?: number
          search?: string
          sortcolumn?: string
          sortorder?: string
        }
        Returns: {
          name: string
          id: string
          updated_at: string
          created_at: string
          last_accessed_at: string
          metadata: Json
        }[]
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

