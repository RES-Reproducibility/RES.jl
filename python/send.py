

import os.path
import base64

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from email.message import EmailMessage


SCOPES = ["https://www.googleapis.com/auth/gmail.compose"]


def gmail_send_mail():
    """send email.
    Print the returned draft's message and id.
    Returns: Draft object, including draft id and message meta data.

    Print the returned  message id
      Returns: Message object, including message id

    """
    # creds, _ = google.auth.default()

    creds = None
    # The file token.json stores the user's access and refresh tokens, and is
    # created automatically when the authorization flow completes for the first
    # time.
    if os.path.exists("draftstoken.json"):
        creds = Credentials.from_authorized_user_file("draftstoken.json", SCOPES)
    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                "credentials.json", SCOPES
            )
        creds = flow.run_local_server(port=0)
        # Save the credentials for the next run
        with open("draftstoken.json", "w") as token:
            token.write(creds.to_json())
    

    try:
        # create gmail api client
        service = build("gmail", "v1", credentials=creds)
        message = EmailMessage()

        message.set_content("This is automated draft mail")

        message["To"] = "gduser1@workspacesamples.dev"
        message["From"] = "gduser2@workspacesamples.dev"
        message["Subject"] = "Automated draft"

        # encoded message
        encoded_message = base64.urlsafe_b64encode(message.as_bytes()).decode()

        create_message = {"raw": encoded_message}
        # pylint: disable=E1101
        send_message = (
            service.users()
            .messages()
            .send(userId="me", body=create_message)
            .execute()
        )


    except HttpError as error:
        print(f"An error occurred: {error}")
        send_message = None
    return send_message



if __name__ == "__main__":
  gmail_send_mail()