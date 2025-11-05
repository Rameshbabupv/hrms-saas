#!/usr/bin/env python3
"""
HRMS SaaS User Signup CLI Tool

This script allows you to create a new user account in the HRMS SaaS system.
It makes a REST API call to the signup endpoint and displays the response.

Usage:
    # Interactive mode (prompts for all fields):
    python signup_user.py

    # Command-line arguments:
    python signup_user.py --email user@example.com --password Pass123! --company "My Company"

    # Get JWT token after signup:
    python signup_user.py --email user@example.com --password Pass123! --get-token

Author: Systech Team
Date: November 4, 2025
"""

import argparse
import json
import re
import sys
from typing import Optional, Dict, Any
import requests
from requests.exceptions import RequestException


# Configuration
DEFAULT_API_URL = "http://localhost:8081/api/v1/auth/signup"
DEFAULT_KEYCLOAK_URL = "http://localhost:8090/realms/hrms-saas/protocol/openid-connect/token"
DEFAULT_CLIENT_ID = "hrms-web-app"
DEFAULT_CLIENT_SECRET = "xE39L2zsTFkOjmAt47ToFQRwgIekjW3l"


# ANSI color codes for terminal output
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    END = '\033[0m'


def print_success(message: str):
    """Print success message in green"""
    print(f"{Colors.GREEN}{Colors.BOLD}✓ {message}{Colors.END}")


def print_error(message: str):
    """Print error message in red"""
    print(f"{Colors.RED}{Colors.BOLD}✗ {message}{Colors.END}", file=sys.stderr)


def print_info(message: str):
    """Print info message in blue"""
    print(f"{Colors.BLUE}ℹ {message}{Colors.END}")


def print_warning(message: str):
    """Print warning message in yellow"""
    print(f"{Colors.YELLOW}⚠ {message}{Colors.END}")


def validate_email(email: str) -> bool:
    """Validate email format"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None


def validate_password(password: str) -> tuple[bool, Optional[str]]:
    """
    Validate password strength
    Returns: (is_valid, error_message)
    """
    if len(password) < 8:
        return False, "Password must be at least 8 characters long"

    if not re.search(r'[A-Z]', password):
        return False, "Password must contain at least one uppercase letter"

    if not re.search(r'[a-z]', password):
        return False, "Password must contain at least one lowercase letter"

    if not re.search(r'[0-9]', password):
        return False, "Password must contain at least one digit"

    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        return False, "Password must contain at least one special character"

    return True, None


def validate_phone(phone: str) -> bool:
    """Validate phone number format (optional field)"""
    if not phone:
        return True  # Phone is optional

    # Allow international format: +1234567890 or (123) 456-7890
    pattern = r'^\+?[0-9\s\-\(\)]+$'
    return re.match(pattern, phone) is not None and len(phone) >= 10


def get_user_input(args: argparse.Namespace) -> Dict[str, str]:
    """
    Get user input from command-line args or interactive prompts
    """
    data = {}

    # Email
    if args.email:
        data['email'] = args.email
    else:
        while True:
            email = input(f"{Colors.CYAN}Email address: {Colors.END}").strip()
            if validate_email(email):
                data['email'] = email
                break
            else:
                print_error("Invalid email format. Please try again.")

    # Password
    if args.password:
        data['password'] = args.password
    else:
        import getpass
        while True:
            password = getpass.getpass(f"{Colors.CYAN}Password: {Colors.END}")
            is_valid, error_msg = validate_password(password)
            if is_valid:
                data['password'] = password
                break
            else:
                print_error(f"Invalid password: {error_msg}")

    # Company Name
    if args.company:
        data['companyName'] = args.company
    else:
        company_name = input(f"{Colors.CYAN}Company Name: {Colors.END}").strip()
        if not company_name:
            print_error("Company name is required")
            sys.exit(1)
        data['companyName'] = company_name

    # First Name
    if args.first_name:
        data['firstName'] = args.first_name
    else:
        first_name = input(f"{Colors.CYAN}First Name: {Colors.END}").strip()
        if not first_name:
            print_error("First name is required")
            sys.exit(1)
        data['firstName'] = first_name

    # Last Name
    if args.last_name:
        data['lastName'] = args.last_name
    else:
        last_name = input(f"{Colors.CYAN}Last Name: {Colors.END}").strip()
        if not last_name:
            print_error("Last name is required")
            sys.exit(1)
        data['lastName'] = last_name

    # Phone (optional)
    if args.phone:
        if validate_phone(args.phone):
            data['phone'] = args.phone
        else:
            print_warning("Invalid phone format, skipping...")
    else:
        phone = input(f"{Colors.CYAN}Phone (optional, press Enter to skip): {Colors.END}").strip()
        if phone:
            if validate_phone(phone):
                data['phone'] = phone
            else:
                print_warning("Invalid phone format, skipping...")

    return data


def signup_user(api_url: str, data: Dict[str, str]) -> Dict[str, Any]:
    """
    Make REST API call to signup endpoint
    """
    try:
        print_info(f"Sending signup request to {api_url}...")

        response = requests.post(
            api_url,
            json=data,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )

        # Parse response
        try:
            response_data = response.json()
        except json.JSONDecodeError:
            response_data = {'error': 'Invalid JSON response', 'text': response.text}

        # Check status code
        if response.status_code == 201 or response.status_code == 200:
            return {'success': True, 'data': response_data, 'status_code': response.status_code}
        else:
            return {
                'success': False,
                'data': response_data,
                'status_code': response.status_code,
                'error': response_data.get('message', 'Unknown error')
            }

    except RequestException as e:
        return {
            'success': False,
            'error': f"Network error: {str(e)}",
            'status_code': None
        }


def get_jwt_token(keycloak_url: str, email: str, password: str,
                  client_id: str, client_secret: str) -> Optional[str]:
    """
    Get JWT token from Keycloak after successful signup
    """
    try:
        print_info("Requesting JWT token from Keycloak...")

        response = requests.post(
            keycloak_url,
            data={
                'grant_type': 'password',
                'client_id': client_id,
                'client_secret': client_secret,
                'username': email,
                'password': password
            },
            headers={'Content-Type': 'application/x-www-form-urlencoded'},
            timeout=10
        )

        if response.status_code == 200:
            token_data = response.json()
            return token_data.get('access_token')
        else:
            print_warning(f"Failed to get token: {response.status_code}")
            return None

    except RequestException as e:
        print_warning(f"Token request failed: {str(e)}")
        return None


def print_response(result: Dict[str, Any], show_token: bool = False,
                   token: Optional[str] = None):
    """
    Pretty-print the response
    """
    print("\n" + "="*70)

    if result['success']:
        print_success("USER SIGNUP SUCCESSFUL!")
        print("="*70)

        data = result['data']

        # Print response fields
        print(f"\n{Colors.BOLD}Response Details:{Colors.END}")
        print(f"  Status Code: {Colors.GREEN}{result['status_code']}{Colors.END}")

        if data.get('success'):
            print(f"  Success: {Colors.GREEN}{data['success']}{Colors.END}")

        if data.get('message'):
            print(f"  Message: {data['message']}")

        if data.get('tenantId'):
            print(f"\n{Colors.BOLD}{Colors.CYAN}  Tenant ID: {data['tenantId']}{Colors.END}")

        if data.get('userId'):
            print(f"  User ID: {data['userId']}")

        if data.get('requiresEmailVerification'):
            print(f"  Requires Email Verification: {data['requiresEmailVerification']}")

        # Print all response data
        print(f"\n{Colors.BOLD}Full Response:{Colors.END}")
        print(json.dumps(data, indent=2))

        # Print JWT token if requested
        if show_token and token:
            print(f"\n{Colors.BOLD}JWT Access Token:{Colors.END}")
            print(f"{Colors.YELLOW}{token[:50]}...{Colors.END}")
            print(f"\n{Colors.BOLD}Full Token (copy this):{Colors.END}")
            print(token)

            # Decode JWT claims (optional - requires jwt library)
            try:
                import base64
                # Decode payload (middle part of JWT)
                parts = token.split('.')
                if len(parts) == 3:
                    payload = parts[1]
                    # Add padding if needed
                    padding = 4 - len(payload) % 4
                    if padding != 4:
                        payload += '=' * padding

                    decoded = base64.b64decode(payload)
                    claims = json.loads(decoded)

                    print(f"\n{Colors.BOLD}JWT Claims:{Colors.END}")
                    print(json.dumps(claims, indent=2))
            except Exception:
                pass  # JWT decoding is optional

    else:
        print_error("USER SIGNUP FAILED!")
        print("="*70)

        if result.get('status_code'):
            print(f"\n  Status Code: {Colors.RED}{result['status_code']}{Colors.END}")

        if result.get('error'):
            print(f"  Error: {result['error']}")

        if result.get('data'):
            print(f"\n{Colors.BOLD}Response Data:{Colors.END}")
            print(json.dumps(result['data'], indent=2))

    print("\n" + "="*70 + "\n")


def save_to_file(data: Dict[str, Any], filename: str):
    """
    Save response data to JSON file
    """
    try:
        with open(filename, 'w') as f:
            json.dump(data, f, indent=2)
        print_success(f"Response saved to {filename}")
    except Exception as e:
        print_warning(f"Failed to save to file: {str(e)}")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='HRMS SaaS User Signup CLI Tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive mode:
  python signup_user.py

  # With command-line arguments:
  python signup_user.py --email user@example.com --password Pass123! --company "My Company" --first-name John --last-name Doe

  # Get JWT token after signup:
  python signup_user.py --email user@example.com --password Pass123! --get-token

  # Save response to file:
  python signup_user.py --email user@example.com --password Pass123! --save response.json
        """
    )

    parser.add_argument('--email', '-e', help='User email address')
    parser.add_argument('--password', '-p', help='User password')
    parser.add_argument('--company', '-c', help='Company name')
    parser.add_argument('--first-name', '-f', help='First name')
    parser.add_argument('--last-name', '-l', help='Last name')
    parser.add_argument('--phone', help='Phone number (optional)')
    parser.add_argument('--api-url', default=DEFAULT_API_URL,
                       help=f'Signup API URL (default: {DEFAULT_API_URL})')
    parser.add_argument('--get-token', action='store_true',
                       help='Get JWT token after successful signup')
    parser.add_argument('--keycloak-url', default=DEFAULT_KEYCLOAK_URL,
                       help=f'Keycloak token URL (default: {DEFAULT_KEYCLOAK_URL})')
    parser.add_argument('--client-id', default=DEFAULT_CLIENT_ID,
                       help=f'Keycloak client ID (default: {DEFAULT_CLIENT_ID})')
    parser.add_argument('--client-secret', default=DEFAULT_CLIENT_SECRET,
                       help='Keycloak client secret')
    parser.add_argument('--save', '-s', metavar='FILENAME',
                       help='Save response to JSON file')
    parser.add_argument('--no-color', action='store_true',
                       help='Disable colored output')

    args = parser.parse_args()

    # Disable colors if requested
    if args.no_color:
        for attr in dir(Colors):
            if not attr.startswith('_'):
                setattr(Colors, attr, '')

    # Print header
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}  HRMS SaaS User Signup Tool{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}\n")

    # Get user input
    try:
        user_data = get_user_input(args)
    except KeyboardInterrupt:
        print_warning("\n\nSignup cancelled by user")
        sys.exit(0)

    # Display confirmation
    print(f"\n{Colors.BOLD}Summary:{Colors.END}")
    print(f"  Email: {user_data['email']}")
    print(f"  Company: {user_data['companyName']}")
    print(f"  Name: {user_data['firstName']} {user_data['lastName']}")
    if 'phone' in user_data:
        print(f"  Phone: {user_data['phone']}")

    # Make signup request
    result = signup_user(args.api_url, user_data)

    # Get JWT token if requested and signup was successful
    token = None
    if args.get_token and result['success']:
        token = get_jwt_token(
            args.keycloak_url,
            user_data['email'],
            user_data['password'],
            args.client_id,
            args.client_secret
        )

    # Print response
    print_response(result, show_token=args.get_token, token=token)

    # Save to file if requested
    if args.save and result['success']:
        save_data = result['data'].copy()
        if token:
            save_data['jwt_token'] = token
        save_to_file(save_data, args.save)

    # Exit with appropriate code
    sys.exit(0 if result['success'] else 1)


if __name__ == '__main__':
    main()
