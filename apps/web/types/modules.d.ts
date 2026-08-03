// Type declarations for third-party modules that don't have proper type definitions

declare module "googleapis-common" {
  export type GaxiosResponseWithHTTP2<T> = any;
}

// Google APIs - full any type to avoid complex type issues

// Google APIs - full any type to avoid complex type issues
declare module "googleapis" {
  export const google: any;
  export namespace calendar_v3 {
    namespace Schema {
      export type Calendar = any;
      export type Event = any;
      export type CalendarListEntry = any;
      export type EventDateTime = any;
    }
    // Export Schema$ types for compatibility
    export type Schema$CalendarListEntry = any;
    export type Schema$EventDateTime = any;

    class Calendar {
      calendarList: any;
      calendarlist: any;
      events: any;
    }
  }
  export namespace docs_v1 {
    namespace Schema {
      export type Document = any;
      export type StructuralElement = any;
    }
    export type Schema$StructuralElement = any;

    class Docs {
      documents: any;
    }
  }
  export namespace drive_v3 {
    namespace Schema {
      export type File = any;
    }
    export type Schema$File = any;

    class Drive {
      files: any;
    }
  }
  export namespace gmail_v1 {
    namespace Schema {
      export type Message = any;
      export type MessagePart = any;
      export type Thread = any;
      export type Label = any;
    }
    export type Schema$Message = any;
    export type Schema$MessagePart = any;

    class Gmail {
      users: any;
    }
  }
  export namespace people_v1 {
    class People {
      people: any;
      otherContacts: any;
    }
  }
  export namespace oauth2_v2 {
    class Oauth2 {
      tokeninfo: any;
      userinfo: any;
    }
  }

  export const auth: any;
  export const Auth: any;
  export const computeEngine: any;

  export namespace google {
    function calendar(options: any): calendar_v3.Calendar;
    function docs(options: any): docs_v1.Docs;
    function drive(options: any): drive_v3.Drive;
    function gmail(options: any): gmail_v1.Gmail;
    function people(options: any): people_v1.People;
    function oauth2(): oauth2_v2.Oauth2;
  }
}

// Notion Client
declare module "@notionhq/client" {
  export interface BlockObjectResponse {
    id: string;
    [key: string]: any;
  }
  export interface ListBlockChildrenResponse {
    results: BlockObjectResponse[];
    [key: string]: any;
  }
  export interface PageObjectResponse {
    id: string;
    [key: string]: any;
  }
  export interface DatabaseObjectResponse {
    id: string;
    [key: string]: any;
  }

  export interface Client {
    users: any;
    blocks: any;
    databases: any;
    search: any;
    pages: any;
  }

  export const Client: {
    new (options: { auth: string }): Client;
  };
}

declare module "@notionhq/client/build/src/api-endpoints" {
  export interface BlockObjectResponse {
    id: string;
    [key: string]: any;
  }
  export interface ListBlockChildrenResponse {
    results: BlockObjectResponse[];
    [key: string]: any;
  }
  export interface PageObjectResponse {
    id: string;
    [key: string]: any;
  }
  export interface DatabaseObjectResponse {
    id: string;
    [key: string]: any;
  }

  export const APIPath: any;
  export const APITypes: any;
}
