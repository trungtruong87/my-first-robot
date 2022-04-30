*** Settings ***
Documentation     Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images.
Library           RPA.Browser.Selenium    auto_close=${FALSE}
Library           RPA.HTTP
Library           RPA.Tables
Library           RPA.PDF
Library           RPA.FileSystem
Library           RPA.Archive
Library           DateTime
Library           RPA.Robocorp.Vault
Library           RPA.Dialogs

*** Variables ***
${DATA_DIR}       D:${/}RPA${/}Playground${/}my-first-robot${/}data
${CSV_URL}        https://robotsparebinindustries.com/orders.csv
${ORDER_SITE_URL}    https://robotsparebinindustries.com/#/robot-order
${CSV_LOCAL_DIR}    ${DATA_DIR}${/}orders.csv

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Ask to confirm URL to download thr CSV file
    Log credential from Control Room's Vault
    Get the orders.csv file
    Navigate to the order website
    Close the annoying modal
    Fill the form using data from orders.csv file
    Zip the receipts
    [Teardown]    Close Browser

*** Keywords ***
Navigate to the order website
    Open Available Browser    ${ORDER_SITE_URL}
    Maximize Browser Window

Close the annoying modal
    Wait Until Element Is Enabled    xpath://div[@class="modal" and @style="display: block;"]
    Wait Until Keyword Succeeds    5x    10s    Click Element    xpath://*[text()="OK"]

Fill the form using data from orders.csv file
    ${table}=    Read table from CSV    ${DATA_DIR}${/}orders.csv    header:True
    ${table_dimensions}=    Get table dimensions    ${table}
    Log    Table has ${table_dimensions}[0] rows and ${table_dimensions}[1] columns.
    FOR    ${i}    IN RANGE    ${table_dimensions}[0]
        ${row_data}=    Get Table Row    ${table}    ${i}    as_list:True
        Log    ${row_data}
        Select From List By Value    id:head    ${row_data}[1]
        Select Radio Button    body    ${row_data}[2]
        Input Text    xpath://input[@type="number"]    ${row_data}[3]
        Input Text    id:address    ${row_data}[4]
        Click Element When Visible    id:preview
        Wait Until Keyword Succeeds    10x    1s    Click Element    id:order
        # Handle server error - TO DO: Need to fix logic here to use WHILE LOOP instead of IF
        ${error_flag}=    Does Page Contain Element    xpath://div[@class='alert alert-danger']
        IF    ${error_flag} == True
            Press Keys    id:order    ENTER
            ${error_flag}=    Does Page Contain Element    xpath://div[@class='alert alert-danger']
            IF    ${error_flag} == True
                Press Keys    id:order    ENTER
            END
        END
        # Save receipt as PDF
        ${receipt_html}=    Get Element Attribute    id:receipt    outerHTML
        Html To Pdf    ${receipt_html}    ${DATA_DIR}${/}receipts${/}order_${row_data}[0]_receipt.pdf
        # Save robot screenshot as PNG
        Screenshot    id:robot-preview-image    ${DATA_DIR}${/}robot_screenshots${/}order_${row_data}[0]_screenshot.png
        # Add screenshot to receipt PDF
        ${receipt_pdf}=    Open Pdf    ${DATA_DIR}${/}receipts${/}order_${row_data}[0]_receipt.pdf
        ${robot_png}=    Create List    ${DATA_DIR}${/}receipts${/}order_${row_data}[0]_receipt.pdf
        ...    ${DATA_DIR}${/}robot_screenshots${/}order_${row_data}[0]_screenshot.png:align=center
        Add Files To Pdf    ${robot_png}    ${DATA_DIR}${/}receipts${/}order_${row_data}[0]_receipt.pdf
        Close Pdf    ${receipt_pdf}
        Order another robot
        Close the annoying modal
    END

Order another robot
    Click Element    id:order-another

Get the orders.csv file
    Download    ${CSV_URL}    ${DATA_DIR}${/}orders.csv

Zip the receipts
    ${date} =    Get Current Date
    Archive Folder With Zip    ${DATA_DIR}${/}receipts    ${DATA_DIR}${/}robot_order_receipt.zip    recursive=True    include=*.pdf

Log credential from Control Room's Vault
    # I understand security concern. This is just for testing purposes.
    ${secret}=    Get Secret    robotsparebinindustries_credential
    Log    ${secret}[username]
    Log    ${secret}[password]

Ask to confirm URL to download thr CSV file
    Add icon    Warning
    Add heading    Is the URL to download CSV file correct?
    Add text    ${CSV_URL}
    Add submit buttons    buttons=No,Yes    default=Yes
    ${result}=    Run dialog
    IF    $result.submit == "Yes"
        Log    User confirmed the CSV download URL
    ELSE
        Input dialog
    END

Input dialog
    Add heading    Waiting for user input...
    Add text input    url    label=URL
    ...    placeholder=Enter URL here
    ${result}=    Run dialog
    ${CSV_URL}=    Set Variable    ${result}[url]
