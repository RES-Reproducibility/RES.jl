

function sendmail()
    opt = SendOptions(
    isSSL = true,
    username = "ejdataeditor",
    passwd = ENV["DE_gmail"],
    verbose = true)

    #Provide the message body as RFC5322 within an IO
    body = IOBuffer(
        "Date: Fri, 18 Oct 2013 21:44:29 +0100\r\n" *
        "From: You <you@gmail.com>\r\n" *
        "To: me@test.com\r\n" *
        "Subject: Julia Test\r\n" *
        "\r\n" *
        "Test Message\r\n")
    url = "smtp://smtp.gmail.com:587"
    rcpt = ["<florian.oswald@gmail.com>", "<florian.oswald@sciencespo.fr>"]
    from = "<ejdataeditor@gmail.com>"
    resp = send(url, rcpt, from, body, opt)
end